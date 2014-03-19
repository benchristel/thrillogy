require_relative 'thrillogy'

class EyeOfSauron < Thrillogy::Hooks
  def around
    puts "before #{receiver.class}##{method_name} - #{options[:me]}"
    run
    puts "after #{receiver.class}##{method_name} - #{options[:me]}"
  end
end

class Drogo
  def name
    'Drogo'.tap { |s| puts s }
  end
  
  EyeOfSauron.on self, :name, :me => 'Drogo'
end

class Frodo < Drogo
  def name
    (super || 'Frodo').tap { |s| puts s }
  end
  
  EyeOfSauron.on self, :name, :me => 'Frodo'
end

Frodo.new.name
