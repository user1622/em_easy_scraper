# frozen_string_literal: true

module EmEasyScraper
  class Pool
    def initialize(actions_per_period: 10, period: 1.minute)
      @resources = EM::Queue.new
      @removed = []
      @contents = []
      @paused = []
      @rejected_task = {}
      @pause = false
      @rate_limit = Config.instance.auto_delay_call.new(actions_per_period: actions_per_period, period: period)
    end

    def add(resource)
      @contents << resource
      requeue(resource)
    end

    def remove(resource)
      @contents.delete(resource)
      @removed << resource
    end

    def contents
      @contents.dup
    end

    def on_error(*arg, &block)
      @on_error = EM::Callback(*arg, &block)
    end

    def on_done(*arg, &block)
      @on_done = EM::Callback(*arg, &block)
    end

    def paused?
      @pause
    end

    def work_done?
      return false if @rejected_task.any?

      (@resources.size - @removed.size + @paused.size) == @contents.size ||
        (@resources.size + @paused.size) == @contents.size
    end

    def current_pool_size
      @resources.size
    end

    def perform(task, rate_limit_key, &block)
      reject_work = proc do |delay|
        EmEasyScraper.logger.debug("Task with key #{rate_limit_key} was rejected because of rate limit."\
" Will try through #{delay} seconds")
        @rejected_task[task_checksum(task)] = task
        EM.add_timer(delay) { reschedule(task, rate_limit_key, &block) }
      end
      @rate_limit.execute(rate_limit_key, reject: reject_work) do
        @resources.pop do |worker|
          @rejected_task.delete(task_checksum(task))
          if removed?(worker)
            @removed.delete(worker)
            reschedule(task, rate_limit_key, &block)
          else
            work = EM::Callback(task, &block)
            process(work, worker)
          end
        end
      end
    end

    alias reschedule perform

    def num_waiting
      @resources.num_waiting + @rejected_task.size
    end

    def removed?(resource)
      @removed.include?(resource)
    end

    protected

    def requeue(resource)
      @pause ? @paused.push(resource) : @resources.push(resource)
    end

    def failure(resource)
      if @pause
        @paused.push(resource)
      elsif @on_error
        @contents.delete(resource)
        @on_error.call(resource)
        @removed.delete(resource)
      else
        requeue(resource)
      end
    end

    def completion(deferrable, resource)
      deferrable.callback do
        requeue(resource)
        EM.next_tick { @on_done&.call } if work_done?
      end
      deferrable.errback do
        failure(resource)
        EM.next_tick { @on_done&.call } if work_done?
      end
    end

    def process(work, resource)
      deferrable = work.call(resource)
      raise(ArgumentError, 'deferrable expected from work') unless deferrable.is_a?(EM::Deferrable)

      completion(deferrable, resource)
    rescue StandardError
      failure(resource)
      raise
    end

    def task_checksum(task)
      task.object_id
    end
  end
end
