# this assumes you're in the thrillogy root dir when running the spec; i.e. the
# parent dir of lib.
require './lib/thrillogy'

require 'minitest/autorun'
require 'minitest/unit'
require 'minitest/spec'
require 'minitest/mock'

#####################
# DRAMATIS PERSONAE #
#####################

class Audience
  @@memories = []
  
  class << self
    def remember scene
      @@memories << scene
      scene
    end
    
    def recall
      @@memories
    end
    
    # returns true iff the audience recalls the scenes happening in the given
    # order.
    def recall? *scenes
      unmatched = scenes.dup
      @@memories.each do |memory|
        unmatched.shift if unmatched[0] == memory
      end
      unmatched.empty?
    end
    
    def must_recall *scenes
      recall?(*scenes).must_equal true
    end
    
    def wont_recall *scenes
      recall?(*scenes).must_equal false
    end
    
    def forget
      @@memories.clear
    end
  end
end

############################################
# Prologue: Installing Thrillogy Callbacks #
############################################

describe 'installing Thrillogy callbacks' do
  before do
    Audience.forget
    
    @_StageManager = Class.new Thrillogy::Callbacks do
      def before
        Audience.remember "ENTER ROMEO"
      end
    end
  end
  
  describe 'using a callback class' do
    describe 'on an instance method' do
      after do
        _SM = @_StageManager
        _method = @method
        
        _Romeo = Class.new do
          def speak
            Audience.remember 'I AM A ROMEO'
          end
          
          _SM.public_send _method, self, :speak
        end
        
        _Romeo.new.speak
        Audience.must_recall "ENTER ROMEO", "I AM A ROMEO"
      end
      
      it 'works with .on' do
        @method = :on
      end
      
      it 'works with .from' do
        @method = :from
      end
      
      it 'works with .when' do
        @method = :when
      end
      
      it 'works with .to' do
        @method = :to
      end
    end
    
    describe 'on a nonexistent method' do
      it 'raises a NameError' do
        begin
          StageManager.on Class.new, :kill_banquo
        rescue Exception => e
          e.class.must_equal NameError
        end
      end
      
      # PENDING
      #it 'says the method does not exist'
    end
    
    describe 'on a class method' do
      it 'works' do
        _StageManager = @_StageManager
        
        _Romeo = Class.new do
          def self.speak
            Audience.remember 'I AM ROMEO'
          end
          
          metaclass = (class << self; self end)
          
          _StageManager.on metaclass, :speak
        end
        
        _Romeo.speak
        Audience.must_recall "ENTER ROMEO", "I AM ROMEO"
      end
    end
    
    describe 'from multiple callback classes' do
      it 'calls the callbacks from both classes' do
        _StageManager = @_StageManager
        _Director = Class.new Thrillogy::Callbacks do
          def before
            Audience.remember "From the top!"
          end
        end
        
        _Romeo = Class.new do
          def speak
            Audience.remember 'I AM A ROMEO'
          end
          
          _StageManager.on self, :speak
          _Director.on self, :speak
        end
        
        _Romeo.new.speak
        
        Audience.must_recall 'From the top!', 'ENTER ROMEO', 'I AM A ROMEO'
      end
    end
  end
  
  describe 'using a callback definition block' do
    it 'works' do
      _Romeo = Class.new do
        def speak
          Audience.remember 'I AM A ROMEO'
        end
        
        Thrillogy::Callbacks.on self, :speak do
          def before
            Audience.remember 'ENTER ROMEO'
          end
        end
      end
      
      _Romeo.new.speak
      
      Audience.must_recall 'ENTER ROMEO'
    end
  end
end

##############################
# Act I: Thrillogy Callbacks #
##############################

describe 'Thrillogy callbacks' do
  before { Audience.forget }
  
  describe 'a before callback' do
    before do
      @_StageManager = Class.new Thrillogy::Callbacks do
        def before
          Audience.remember "ENTER"
        end
      end
      _StageManager = @_StageManager
      
      @_Romeo = Class.new do
        def wax_poetic
          Audience.remember "What light through yonder window breaks?"
        end
        
        _StageManager.on self, :wax_poetic
      end
      
      @_Romeo.new.wax_poetic rescue nil
    end
    
    it 'is called before the main event' do
      Audience.must_recall "ENTER", "What light through yonder window breaks?"
    end
    
    it 'is called only once' do
      Audience.wont_recall "ENTER", "ENTER"
    end
    
    describe 'when the callback raises' do
      before do
        @_StageManager.class_eval do
          def before
            raise "oops"
          end
        end
      end
      
      it 'the exception is not rescued' do
        lambda { @_Romeo.new.wax_poetic }.must_raise RuntimeError
      end
    end
  end
  
  describe 'an after callback' do
    before do
      _StageManager = Class.new Thrillogy::Callbacks do
        def after
          Audience.remember "EXIT"
        end
      end
      
      _Romeo = Class.new do
        def wax_poetic
          Audience.remember "What light through yonder window breaks?"
        end
        
        _StageManager.on self, :wax_poetic
      end
      
      _Romeo.new.wax_poetic
    end
    
    it 'is called after the main event' do
      Audience.must_recall(
        "What light through yonder window breaks?",
        "EXIT" )
    end
    
    it 'is called only once' do
      Audience.wont_recall "EXIT", "EXIT"
    end
  end
  
  describe 'the around callback' do
    before do
      $the_show_must_go_on = true
      
      _StageManager = Class.new Thrillogy::Callbacks do
        def around
          Audience.remember "The curtain rises"
          run if $the_show_must_go_on
          Audience.remember "The curtain falls"
        end
        
        def before
          Audience.remember "ENTER"
        end
        
        def after
          Audience.remember "EXIT"
        end
      end
      
      @_Romeo = Class.new do
        def wax_poetic
          Audience.remember "What light through yonder window breaks?"
        end
        
        _StageManager.on self, :wax_poetic
      end
    end
    
    it 'is called around the main event' do
      @_Romeo.new.wax_poetic
      
      Audience.must_recall(
        "The curtain rises",
        "What light through yonder window breaks?",
        "The curtain falls" )
    end
    
    it 'is called around the before and after callbacks' do
      @_Romeo.new.wax_poetic
      
      Audience.must_recall(
        "The curtain rises",
        "ENTER",
        "EXIT",
        "The curtain falls" )
    end
    
    it 'is called only once' do
      @_Romeo.new.wax_poetic
      
      Audience.wont_recall(
        "The curtain rises",
        "The curtain rises" )
    end
    
    describe 'when `run` is not called from the `around` callback' do
      before do
        $the_show_must_go_on = false
      end
      
      it 'raises a RuntimeError' do
        lambda { @_Romeo.new.wax_poetic }.must_raise RuntimeError
      end
    end
  end
  
  describe 'the on_exception callback' do
    before do      
      _StageManager = Class.new Thrillogy::Callbacks do
        def on_exception
          Audience.remember "That was supposed to happen"
        end
      end
      
      @_Romeo = Class.new do
        def wax_poetic(remembered_lines=true)
          if not remembered_lines
            raise 'THERE WAS A FARMER HAD A DOG AND ROME-O WAS HIS NAME-O'
          end
        end
        
        _StageManager.on self, :wax_poetic
      end
    end
    
    it 'is called when the main event raises' do
      @_Romeo.new.wax_poetic(false) rescue nil
      
      Audience.must_recall "That was supposed to happen"
    end
    
    it 're-raises the exception' do
      lambda { @_Romeo.new.wax_poetic(false) }.must_raise RuntimeError
    end
    
    it "is not called when the main event doesn't raise" do
      @_Romeo.new.wax_poetic
      
      Audience.wont_recall "That was supposed to happen"
    end
    
    it 'is called only once' do
      @_Romeo.new.wax_poetic(false) rescue nil
      
      Audience.wont_recall "That was supposed to happen", "That was supposed to happen"
    end
  end
  
  describe 'the ensure callback' do
    before do
      _StageManager = Class.new Thrillogy::Callbacks do
        def around
          run
          Audience.remember "EXIT"
        end
        
        def on_exception
          Audience.remember "That was supposed to happen"
        end
        
        def ensure
          Audience.remember "And don't you forget it!"
        end
      end
      
      @_Romeo = Class.new do
        def wax_poetic(remembered_lines=true)
          if not remembered_lines
            raise 'THERE WAS A FARMER HAD A DOG AND ROME-O WAS HIS NAME-O'
          end
        end
        
        _StageManager.on self, :wax_poetic
      end
    end
    
    it 'is called when the main event raises' do
      @_Romeo.new.wax_poetic(false) rescue nil
      
      Audience.must_recall "And don't you forget it!"
    end
    
    it 'is called after on_exception' do
      @_Romeo.new.wax_poetic(false) rescue nil
      
      Audience.must_recall "That was supposed to happen", "And don't you forget it!"
    end
    
    it 'is called when the main event does not raise' do
      @_Romeo.new.wax_poetic
      
      Audience.must_recall "And don't you forget it!"
    end
    
    it 'is called after the `around` callback finishes' do
      @_Romeo.new.wax_poetic
      
      Audience.must_recall "EXIT", "And don't you forget it!"
    end
    
    it 'is called only once' do
      @_Romeo.new.wax_poetic
      
      Audience.wont_recall "And don't you forget it!", "And don't you forget it!"
    end
  end
end

#######################################################
# Act II: A Method with Thrillogy Callbacks Installed #
#######################################################

describe 'A method with Thrillogy callbacks installed' do
  before do
    _StageManager = Class.new Thrillogy::Callbacks do
      def before
        "ENTER ROMEO"
      end
    end
    
    @_Romeo = Class.new do
      def wax_poetic heavenly_body="Sun"
        "It is the East, and Juliet is the #{heavenly_body}"
      end
      
      _StageManager.on self, :wax_poetic
    end
  end
  
  it 'returns the correct value' do
    @_Romeo.new.wax_poetic.must_equal "It is the East, and Juliet is the Sun"
  end
  
  it 'accepts passed arguments' do
    @_Romeo.new.wax_poetic('planet Mars').
        must_equal "It is the East, and Juliet is the planet Mars"
  end
  
  it 'yields to a block' do
    @_Romeo.class_eval do
      def wax_poetic
        yield :chunky_bacon
      end
    end
    
    yielded = nil
    @_Romeo.new.wax_poetic do |x|
      yielded = x
    end
    yielded.must_equal :chunky_bacon
  end
end

##################################################
# Act III: Getting Method Call Data In Callbacks #
##################################################

describe 'A callback' do
  before do
    Audience.forget
    
    _StageManager = Class.new Thrillogy::Callbacks do; end
    @_StageManager = _StageManager
    
    @_Romeo = Class.new do
      def name
        'ROMEO'
      end
      
      def wax_poetic heavenly_body="Sun"
        "It is the East, and Juliet is the #{heavenly_body}"
      end
      
      _StageManager.on self, :wax_poetic
    end
  end
  
  it "can get the call's receiver" do
    @_StageManager.class_eval do
      def before
        Audience.remember "ENTER #{receiver.name}"
      end
    end
    
    @_Romeo.new.wax_poetic
    Audience.must_recall "ENTER ROMEO"
  end
  
  it "can get the method name" do
    @_StageManager.class_eval do
      def before
        Audience.remember "Romeo will #{method_name}"
      end
    end
    
    @_Romeo.new.wax_poetic
    Audience.must_recall "Romeo will wax_poetic"
  end
  
  it "can get the call's arguments" do
    @_StageManager.class_eval do
      def before
        Audience.remember "Romeo will #{method_name} about the #{arguments[0]}"
      end
    end
    
    @_Romeo.new.wax_poetic 'Moon'
    Audience.must_recall "Romeo will wax_poetic about the Moon"
  end
  
  it "can get the call's block" do
    @_StageManager.class_eval do
      def before
        Audience.remember "Romeo will #{method_name} with a #{block.class}"
      end
    end
    
    @_Romeo.new.wax_poetic do; end
    Audience.must_recall "Romeo will wax_poetic with a Proc"
  end
  
  it "can get the call's return value" do
    @_StageManager.class_eval do
      def after
        Audience.remember "Romeo said #{returned.inspect}"
      end
    end
    
    @_Romeo.new.wax_poetic
    Audience.must_recall 'Romeo said "It is the East, and Juliet is the Sun"'
  end
  
  it "can get the call's exception" do
    _StageManager = Class.new Thrillogy::Callbacks do
      def on_exception
        Audience.remember "#{exception}"
      end
    end
    
    _Romeo = Class.new do
      def wax_poetic
        raise 'panic'
      end
      
      _StageManager.on self, :wax_poetic
    end
    
    _Romeo.new.wax_poetic rescue nil
    Audience.must_recall 'panic'
  end
  
  it "can get the options passed when the callbacks were installed" do
    _StageManager = Class.new Thrillogy::Callbacks do
      def ensure
        if options[:people_on_stage] > 1
          Audience.remember "EXEUNT"
        else
          Audience.remember "EXIT"
        end
      end
    end
    
    _Romeo = Class.new do
      def wax_poetic
      end
      
      _StageManager.on self, :wax_poetic, :people_on_stage => 2
    end
    
    _Romeo.new.wax_poetic
    Audience.must_recall 'EXEUNT'
  end
end

####################################
# Act IV: Working with Inheritance #
####################################

describe "a subclass of a class with Thrillogy callbacks" do
  describe "with no methods overridden" do
    it "has the same callbacks as its parent" do
      _StageManager = Class.new Thrillogy::Callbacks do
        def before
          Audience.remember 'ENTER'
        end
      end
      
      _Actor = Class.new do
        def speak
          Audience.remember "bloo blee blee bloo"
        end
        
        _StageManager.on self, :speak
      end
      
      _Romeo = Class.new _Actor
      
      _Romeo.new.speak
      Audience.must_recall "ENTER", "bloo blee blee bloo"
    end
  end
  
  describe "with a method overridden with no super call" do
    it "does not have callbacks" do
      
    end
  end
  
  describe "with a method overridden and thrillogy_inherit called" do
    it "has the callbacks of the parent" do
      
    end
    
    describe "when the subclass method calls super" do
      it "runs the callbacks only once" do
        
      end
    end
  end
end
