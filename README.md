thrillogy
=========

Monitor everything without ever writing another logger call.

## Add Callback Hooks to Any Method

```ruby
class AddBasicLogging < Thrillogy::Hooks
  def before
  	Rails.logger.debug "starting #{receiver.class}##{method_name} with #{arguments.join(',')}"
  end

  def after
	Rails.logger.debug "finished #{receiver.class}##{method_name} => #{returned}"
  end

  def on_exception
  	Rails.logger.error "#{receiver}.#{method_name} raised #{exception}"
  end
end


class MyClass
  def product(*args)
  	args.reduce(:*)
  end

  AddBasicLogging.to self, :product
end
```

The above will log the following if you call `MyClass.new.product(1,2,3)`:

```
starting MyClass#product with 1,2,3
finished MyClass#product => 6
```

## Available Hooks

The available callback hooks are:

* before
* after
* around
* on_exception
* ensure

Within the `around` callback, you must call `run` to trigger the method call. `before` and `after` are called inside `around`, and `ensure` is always called last. If the method call raises, `on_exception` is called and the exception is re-raised.

## Method Data Getters

Thrillogy::Hooks also defines getter methods that give you information about the method call.

* receiver
* method_name
* arguments
* block
* returned
* exception
* options

These can be used in any callback, though if you call `returned` or `exception` in a `before` callback, they'll always be nil. The `options` getter is used for a hash of custom data, which you can pass as the final argument of an installer call:

```ruby
class AddBasicLogging < Thrillogy::Hooks
  def after
  	msg = "[#{options[:tag]}] #{receiver}.#{method} => #{returned}"
  	Rails.logger.info msg
  end
end

AddBasicLogging.to User, :create, :tag => 'onboarding'
```

## Installer Methods

Thrillogy::Hooks defines several methods you can use to install your callbacks:

```ruby
DebugCallbacks.on MyClass, :my_method
AddLogging.to MyClass, :my_method
SendEmailAlert.when MyClass, :fail!, :invalidate!
AggregateRuntimeData.from, :MyClass, :method1, :method2
```
