module Thrillogy
  class Callbacks
    @@warning_logger = nil
    
    attr_accessor :call
    
    public
    def around
      run
    end
    
    public
    %w(before after on_exception ensure).each do |meth|
      define_method meth do; end
    end
    
    %w(run receiver method_name arguments block returned exception options).
    each do |meth|
      define_method meth do; call.send meth end
    end
    
    public
    def self.install(*classes_and_methods, &block)
      classes, methods = classes_and_methods.partition { |x| x.is_a? Class }
      callback_definition = block_given? ? block : self
      classes.each do |_class|
        Installer.new(_class, callback_definition).install(*methods)
      end
    end
    
    class << self
      [:on, :to, :for, :from, :at, :when].each do |_alias|
        alias_method _alias, :install
      end
    end
    
    public
    def self.warning_logger new_warning_logger=@@warning_logger
      @@warning_logger = new_warning_logger
    end
    
    public
    def self.warn(msg)
      warning_logger && warning_logger.warn(msg)
    end
    
    class DefaultWarningLogger
      def warn msg
        $stderr.puts "WARNING: #{msg}"
      end
    end
    
    warning_logger DefaultWarningLogger.new
  end
  
  class Installer
    @@method_seqno = 0
    
    attr_accessor :target, :source
    
    def initialize(target, source)
      self.target = target
      self.source = source
    end
    
    def install(*methods_and_options)
      methods, options = separate(methods_and_options)
      methods.each do |method_name|
        # get attrs into local vars so they will be enclosed by the block passed
        # to define_method
        _target = target 
        _source = source
        _source = Class.new(Callbacks, &_source) if _source.is_a? Proc
        
        aliased = uniquely_rename(method_name)
        target.send :alias_method, aliased, method_name
        target.send :define_method, method_name do |*args, &block|
          MethodCall.new(
            :delegate => _source.new(),
            :receiver => self,
            :method_name => method_name,
            :aliased_method_name => aliased,
            :arguments => args,
            :block => block,
            :options => options,
          ).invoke
        end
      end
    end
    
    def separate methods_and_options
      options, methods = methods_and_options.partition { |x| x.is_a? Hash }
      options = options.inject({}) { |merged, hash| merged.merge hash }
      [methods, options]
    end
    
    def uniquely_rename(name)
      "_#{@@method_seqno += 1}_#{name}"
    end
  end
  
  class MethodCall
    attr_accessor :receiver, :method_name, :aliased_method_name, :arguments,
      :block, :returned, :exception, :options, :delegate, :run_called,
      :call_finished, :current_callback
      
    public
    [:returned, :exception].each do |attr|
      define_method attr do
        if not call_finished
          warn "accessing `#{self.class}##{attr}` from #{current_callback}, where it is not yet set"
        end
        instance_variable_get "@#{attr}"
      end
    end
    
    def warn(*args)
      delegate.class.warn(*args)
    end
    
    public
    [:before, :after, :around, :ensure, :on_exception].each do |callback|
      lambda do
        define_method callback do
          self.current_callback = callback
          delegate.send callback
          self.current_callback = nil
        end
      end.call
    end
      
    def initialize(params={})
      params.each do |k, v|
        self.send "#{k}=", v
      end
      self.run_called = false
      self.call_finished = false
      self.current_callback = nil
    end
    
    def delegate= new_delegate
      @delegate = new_delegate
      new_delegate.call = self
    end
      
    def run
      self.run_called = true
      before
      begin
        self.returned = receiver.send aliased_method_name, *arguments, &block
      ensure
        self.call_finished = true
      end
      after
      returned
    end
    
    def invoke
      begin
        around
        raise "run not called" if not run_called
        returned
      rescue Exception => e
        self.exception = e
        on_exception
        raise e
      ensure
        self.ensure
      end
    end
  end
end