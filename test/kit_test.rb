# encoding: UTF-8

require 'test_helper'

describe Vines::Kit do
  describe '#hmac' do
    it 'generates a SHA-512 HMAC' do
      Vines::Kit.hmac('secret', 'username').length.must_equal 128
      assert_equal Vines::Kit.hmac('s1', 'u1'), Vines::Kit.hmac('s1', 'u1')
      refute_equal Vines::Kit.hmac('s1', 'u1'), Vines::Kit.hmac('s2', 'u1')
      refute_equal Vines::Kit.hmac('s1', 'u1'), Vines::Kit.hmac('s1', 'u2')
    end
  end

  describe '#uuid' do
    it 'returns a random uuid' do
      ids = Array.new(1000) { Vines::Kit.uuid }
      assert ids.all? {|id| !id.nil? }
      assert ids.all? {|id| id.length == 36 }
      assert ids.all? {|id| id.match(/\w{8}-\w{4}-[4]\w{3}-[89ab]\w{3}-\w{12}/) }
      ids.uniq.length.must_equal ids.length
    end
  end

  describe '#auth_token' do
    it 'returns a random 128 character token' do
      Vines::Kit.auth_token.wont_equal Vines::Kit.auth_token
      Vines::Kit.auth_token.length.must_equal 128
    end
  end
end
