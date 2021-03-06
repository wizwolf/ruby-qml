require 'singleton'
require 'monitor'

module QML

  class Dispatcher
    include Singleton
    include MonitorMixin

    MAX_DURATION = 1/10.to_r

    def initialize
      super
      @tasks = []
    end

    def add_task(&task)
      synchronize do
        Kernel.set_event_loop_hook_enabled_later true if @tasks.empty?
        @tasks << task
      end
    end

    def empty?
      synchronize do
        @tasks.empty?
      end
    end

    def run_tasks
      synchronize do
        start_time = Time.now
        loop do
          break if @tasks.empty?
          break if start_time.to_r - Time.now.to_r > MAX_DURATION
          task = @tasks.shift
          task.call
        end
        Kernel.set_event_loop_hook_enabled_later false if @tasks.empty?
      end
    end
  end

  on_init do
    Kernel.event_loop_hook_timer.timeout.connect do
      Dispatcher.instance.run_tasks
    end
  end

  # Runs a block asynchronously within the event loop.
  #
  # QML UI is not thread-safe and can only be accessed from the main thread.
  # Use this method to set results of asynchronous tasks to UI.
  # @example
  #   def on_button_clicked
  #     Thread.new do
  #       result = do_task
  #       QML.later do
  #         set_result_to_ui(result)
  #       end
  #     end
  #   end
  # @see Dispatchable#later
  # @see Dispatcher#add_task
  def later(&block)
    Dispatcher.instance.add_task(&block)
  end
  module_function :later
end
