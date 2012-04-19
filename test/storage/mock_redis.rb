# encoding: UTF-8

# A mock redis storage implementation that saves data to an in-memory Hash.
class MockRedis
  attr_reader :db

  # Mimic em-hiredis behavior.
  def self.defer(method)
    old = instance_method(method)
    define_method method do |*args, &block|
      result = old.bind(self).call(*args)
      deferred = EM::DefaultDeferrable.new
      deferred.callback(&block) if block
      EM.next_tick { deferred.succeed(result) }
      deferred
    end
  end

  def initialize
    @db = {}
  end

  def del(key)
    @db.delete(key)
  end
  defer :del

  def get(key)
    @db[key]
  end
  defer :get

  def set(key, value)
    @db[key] = value
  end
  defer :set

  def hget(key, field)
    @db[key][field] rescue nil
  end
  defer :hget

  def hdel(key, field)
    @db[key].delete(field) rescue nil
  end
  defer :hdel

  def hgetall(key)
    (@db[key] || {}).map do |k, v|
      [k, v]
    end.flatten
  end
  defer :hgetall

  def hset(key, field, value)
    @db[key] ||= {}
    @db[key][field] = value
  end
  defer :hset

  def hmset(key, *args)
    @db[key] = Hash[*args]
  end
  defer :hmset

  def sadd(key, obj)
    @db[key] ||= Set.new
    @db[key] << obj
  end
  defer :sadd

  def srem(key, obj)
    @db[key].delete(obj) rescue nil
  end
  defer :srem

  def smembers
    @db[key].to_a rescue []
  end
  defer :smembers

  def flushdb
    @db.clear
  end
  defer :flushdb

  def multi
    @transaction = true
  end
  defer :multi

  def exec
    raise 'transaction must start with multi' unless @transaction
    @transaction = false
  end
  defer :exec
end