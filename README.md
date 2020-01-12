# Delayer

[![toshia](https://circleci.com/gh/toshia/delayer.svg?style=svg)](https://circleci.com/gh/toshia/delayer)

Delay Any task. Similar priority-queue.

## Installation

Add this line to your application's Gemfile:

    gem 'delayer'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install delayer

## Usage

    Task = Delayer.generate_class # Define basic class
    Task = Delayer.generate_class(priority: [:high, :middle, :low], default: :middle) # or, Priority delayer
    Task = Delayer.generate_class(expire: 0.5) # and/or, Time limited delayer.
    
    task = Task.new { delayed code ... } # Register task
    task = Task.new(:high) { delayed code ... } # or, You can specify priority.
    
    task.cancel # Task can cancel before Delayer#run.
    
    Task.run # Execute all tasks.
    Task.run(1) # or, You can specify expire.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
