require_relative 'thrillogy'

class QueenElizabeth
  @@annoyances = []
  
  def self.wills_that something_should_be_done
    if block_given? and yield
      praise something_should_be_done
    else
      scowl "We are not amused; #{something_should_be_done}!"
    end
  end
  
  def self.praise a_thing
    print '.'
  end
  
  def self.scowl something_wrong
    print 'F'
    @@annoyances << something_wrong
  end
  
  def self.opine
    puts ''
    if @@annoyances.empty?
      puts "*applause*"
    else
      puts @@annoyances
    end
  end
end

class Audience
  @@memories = []
  
  class << self
    def remember scene
      @@memories << scene
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
    
    def forget
      @@memories.clear
    end
    
    def gasp
      remember 'Gasp!'
    end
    
    def react scene
      remember 'Yay!' if scene == :happy
      remember 'Boo!' if scene == :sappy
    end
  end
end

class Hamlet
  def soliloquy(others_on_stage=nil)
    raise 'totally goofed' if others_on_stage
    "To be, or not to be?"
  end
  
  def murder(*victims)
    victims.each do |victim|
      yield "Hamlet kills #{victim}!" if block_given?
    end    
  end
  
  def self.die
    "Hamlet is dead!"
  end
end

class WarningLogger
  @@lines = []
  
  def self.warn line
    @@lines << line
  end
  
  def self.read
    @@lines
  end
  
  def self.clear
    @@lines.clear
  end
end

class InviteAudience < Thrillogy::Callbacks
  def around
    Audience.gasp
    run
    Audience.react options[:feels]
  end
  
  def before
    event = "#{receiver.class} is about to do a #{method_name}"
    event += " on #{arguments.join(' and ')}" unless arguments.empty?
    Audience.remember event
  end
  
  def after
    if receiver.is_a? Module
      rcv = "#{receiver}."
    else
      rcv = "#{receiver.class}#"
    end
    
    Audience.remember "#{rcv}#{method_name} was like #{returned.inspect}"
  end
  
  def on_exception
    Audience.remember "#{receiver.class} #{exception}!"
  end
  
  def ensure
    Audience.remember "Hamlet had a soliloquy"
  end
  
  warning_logger WarningLogger
end

InviteAudience.to Hamlet, :soliloquy, :feels => :happy
InviteAudience.to Hamlet, :murder, :feels => :sappy
class << Hamlet
  InviteAudience.to self, :die
end

QueenElizabeth.wills_that "Hamlet's soliloquy should return the correct value" do
  Audience.forget
  Hamlet.new.soliloquy == "To be, or not to be?"
end

QueenElizabeth.wills_that "the audience should see Hamlet's soliloquy" do
  Audience.forget
  Hamlet.new.soliloquy
  Audience.recall? "Hamlet had a soliloquy"
end

QueenElizabeth.wills_that "the audience should remember Hamlet's soliloquy even if he slips on a banana peel" do
  Audience.forget
  begin; Hamlet.new.soliloquy :banana_peel; rescue; end
  Audience.recall? "Hamlet totally goofed!", "Hamlet had a soliloquy"
end

QueenElizabeth.wills_that "the audience should remember what Hamlet said" do
  Audience.forget
  Hamlet.new.soliloquy
  Audience.recall? 'Hamlet#soliloquy was like "To be, or not to be?"'
end

QueenElizabeth.wills_that "the audience should not remember what Hamlet said if he slipped on a banana peel" do
  Audience.forget
  begin; Hamlet.new.soliloquy :banana_peel; rescue; end
  not Audience.recall? 'Hamlet#soliloquy was like "To be, or not to be?"'
end

QueenElizabeth.wills_that "the audience should not remember Hamlet slipping on a banana peel if he didn't" do
  Audience.forget
  Hamlet.new.soliloquy
  not Audience.recall? "Hamlet totally goofed!"
end

QueenElizabeth.wills_that "the audience should remember Hamlet killing people" do
  Audience.forget
  Hamlet.new.murder 'Dumbledore' do |event|
    Audience.remember event
  end
  Audience.recall? 'Hamlet kills Dumbledore!'
end

QueenElizabeth.wills_that "the audience should anticipate Hamlet killing people" do
  Audience.forget
  Hamlet.new.murder 'Polonius', 'Laertes'
  Audience.recall? 'Hamlet is about to do a murder on Polonius and Laertes'
end

QueenElizabeth.wills_that "the audience should cheer if Hamlet does a good thing but boo if he does a bad thing" do
  Audience.forget
  Hamlet.new.soliloquy
  Hamlet.new.murder 'Polonius', 'Laertes'
  Hamlet.die
  Audience.recall? 'Yay!', 'Boo!'
end

QueenElizabeth.wills_that "the audience should anticipate and remember the soliloquy, in that order" do
  Audience.forget
  Hamlet.new.soliloquy
  Audience.recall? 'Gasp!', 'Hamlet is about to do a soliloquy', 
                   'Hamlet#soliloquy was like "To be, or not to be?"', 'Yay!'
end

QueenElizabeth.wills_that "the audience should remember Hamlet's self dying" do
  Audience.forget
  Hamlet.die
  Audience.recall? 'Hamlet.die was like "Hamlet is dead!"'
end

QueenElizabeth.wills_that "we should be warned if we try to use information we don't have" do
  Audience.forget
  WarningLogger.clear
  
  class InviteAudience
    def before
      returned
      exception
    end
    
    def around
      returned
      exception
      run
    end
  end
  
  Hamlet.new.soliloquy
  
  expected = [
    'accessing `Thrillogy::MethodCall#returned` from before, where it is not yet set',
    'accessing `Thrillogy::MethodCall#exception` from before, where it is not yet set',
    'accessing `Thrillogy::MethodCall#returned` from around, where it is not yet set',
    'accessing `Thrillogy::MethodCall#exception` from around, where it is not yet set'
  ]
  
  expected.all? do |i|
    WarningLogger.read.include? i
  end
end

QueenElizabeth.opine