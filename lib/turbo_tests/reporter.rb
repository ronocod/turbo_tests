# frozen_string_literal: true

module TurboTests
  class Reporter
    attr_writer :load_time

    def self.from_config(formatter_config, start_time)
      reporter = new(start_time)

      formatter_config.each do |config|
        name, outputs = config.values_at(:name, :outputs)

        outputs.map! do |filename|
          filename == "-" ? $stdout : File.open(filename, "w")
        end

        reporter.add(name, outputs)
      end

      reporter
    end

    attr_reader :pending_examples
    attr_reader :failed_examples

    def initialize(start_time)
      @formatters = []
      @pending_examples = []
      @failed_examples = []
      @all_examples = []
      @messages = []
      @start_time = start_time
      @load_time = 0
      @errors_outside_of_examples_count = 0
    end

    def add(name, outputs)
      outputs.each do |output|
        formatter_class =
          case name
          when "p", "progress"
            RSpec::Core::Formatters::ProgressFormatter
          when "d", "documentation"
            RSpec::Core::Formatters::DocumentationFormatter
          else
            Kernel.const_get(name)
          end

        @formatters << formatter_class.new(output)
      end
    end

    def group_started(notification)
      delegate_to_formatters(:example_group_started, notification)
    end

    def group_finished(notification)
      delegate_to_formatters(:example_group_finished, notification)
    end

    def example_passed(example)
      delegate_to_formatters(:example_passed, example.notification)

      @all_examples << example
    end

    def example_pending(example)
      delegate_to_formatters(:example_pending, example.notification)

      @all_examples << example
      @pending_examples << example
    end

    def example_failed(example)
      delegate_to_formatters(:example_failed, example.notification)

      @all_examples << example
      @failed_examples << example
    end

    def message(message)
      delegate_to_formatters(:message, RSpec::Core::Notifications::MessageNotification.new(message))
      @messages << message
    end

    def error_outside_of_examples
      @errors_outside_of_examples_count += 1
    end

    def examples
      @all_examples
    end

    def finish
      # SEE: https://bit.ly/2NP87Cz
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      delegate_to_formatters(:stop,
        RSpec::Core::Notifications::ExamplesNotification.new(
          self
        ))
      delegate_to_formatters(:start_dump,
        RSpec::Core::Notifications::NullNotification)
      delegate_to_formatters(:dump_pending,
        RSpec::Core::Notifications::ExamplesNotification.new(
          self
        ))
      delegate_to_formatters(:dump_failures,
        RSpec::Core::Notifications::ExamplesNotification.new(
          self
        ))
      delegate_to_formatters(:dump_summary,
        RSpec::Core::Notifications::SummaryNotification.new(
          end_time - @start_time,
          @all_examples,
          @failed_examples,
          @pending_examples,
          @load_time,
          @errors_outside_of_examples_count
        ))
      delegate_to_formatters(:close,
        RSpec::Core::Notifications::NullNotification)
    end

    def seed_notification(seed, seed_used)
      puts RSpec::Core::Notifications::SeedNotification.new(seed, seed_used).fully_formatted
      puts
    end

    protected

    def delegate_to_formatters(method, *args)
      @formatters.each do |formatter|
        formatter.send(method, *args) if formatter.respond_to?(method)
      end
    end
  end
end
