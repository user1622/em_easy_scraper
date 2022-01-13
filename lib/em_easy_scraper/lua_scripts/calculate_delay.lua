local normal_delay = tonumber(ARGV[1])
local cache_key = KEYS[1]
local timestamp = redis.call('TIME')[1]

local since_last_call
if redis.call('exists', cache_key) == 1
then
    since_last_call = timestamp - redis.call('get', KEYS[1])
else
    since_last_call = normal_delay
end

if since_last_call < normal_delay
then
  return normal_delay - since_last_call
else
  redis.call('set', cache_key, timestamp)
  return 0
end