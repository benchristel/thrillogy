thrillogy
=========

Monitor everything without ever writing another logger call.

## Add Callback Hooks to Any Method

Try it! `cd` into `thrillogy/lib`, run `irb`, and copy-paste this code:

```ruby
require 'thrillogy'

class Hamlet
  def speak
    p "To be, or not to be?"
  end

  def to_s
    'HAMLET'
  end
end

Thrillogy::Callbacks.install Hamlet, :speak do
  def before
    p "ENTER #{receiver}"
  end

  def after
    p "EXIT #{receiver}"
  end

  def around
    p "the curtain rises"
    run
    p "the curtain falls"
  end
end

Hamlet.new.speak
# prints:
#  "the curtain rises"
#  "ENTER HAMLET"
#  "To be, or not to be?"
#  "EXIT HAMLET"
#  "the curtain falls"
#
# and returns:
#  "To be, or not to be?"
```

## What Is It Good For?

You can use Thrillogy to:

- Log the arguments, return values, and exceptions from methods without cluttering your code.
- Make assertions about the arguments and return values of your methods, and raise an exception if the assertions aren't met.
- Quickly add and remove `puts` calls for debugging purposes.
- Quickly add and remove instrumentation when optimizing performance.

You probably SHOULDN'T use it for:

- DRYing out your app logic. Attempts of this kind are likely to lead to nightmarish debugging sessions as you try to figure out why a simple method has tons of inexplicable side effects.

## Available Hooks

The available callback hooks are:

- before
- after
- around
- on_exception
- ensure

Within the `around` callback, you must call `run` to trigger the method call. `before` and `after` are called inside `around`, and `ensure` is always called last. If the method call raises, `on_exception` is called and the exception is re-raised.

## Getting Information About the Method Call in Your Callbacks

Within your callbacks, you can use the following methods to get information about the method call:

- receiver
- method_name
- arguments
- block
- returned
- exception
- options

These can be used in any callback, though if you call `returned` or `exception` in a `before` callback, they'll always be nil. The `options` getter is used for a hash of custom data, which you can pass as the final argument of an installer call:

```ruby
class AddBasicLogging < Thrillogy::Hooks
  def after
    msg = "[#{options[:tag]}] #{receiver}.#{method_name} => #{returned}"
    Rails.logger.info msg
  end
end

AddBasicLogging.to User, :create, :tag => 'onboarding'
```


## Define Named Callback Suites

A callback suite is a class that descends from `Thrillogy::Callbacks`. You can define the hook methods (`before`, `after`, etc.) on a callback suite to add behavior to them.

```ruby
class AddBasicLogging < Thrillogy::Hooks
  def before
  	Rails.logger.debug \
        "starting #{receiver.class}##{method_name} with #{arguments.join(',')}"
  end

  def after
    Rails.logger.debug \
        "finished #{receiver.class}##{method_name} => #{returned}"
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

Thrillogy::Callbacks also defines getter methods that give you information about the method call.

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
  	msg = "[#{options[:tag]}] #{receiver}.#{method_name} => #{returned}"
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
AggregateRuntimeData.from, MyClass, :method1, :method2
```

## Caveats

If you add Thrillogy callbacks to a class, descendents of that class will lose the callback behavior if they override methods of the superclass. You can, of course, add the same callbacks to the subclass's methods, but then if you call `super`, the callbacks will be invoked twice; once for the subclass method call and once for the `super` call.

## TODO

- Add `safe_*` hooks, which catch exceptions raised from their callbacks.

