module EventMachine::Hiredis
  class Client < BaseClient
    def eval_script(lua, lua_sha, keys, args)
      df = EM::DefaultDeferrable.new
      method_missing(:evalsha, lua_sha, keys.size, *keys, *args).callback(
        &df.method(:succeed)
      ).errback { |e|
        puts e
        if e.kind_of?(RedisError) && e.redis_error.message.start_with?("NOSCRIPT")
          method_missing(:eval, lua, keys.size, *keys, *args)
            .callback(&df.method(:succeed)).errback(&df.method(:fail))
        else
          df.fail(e)
        end
      }
      df
    end
  end
end
