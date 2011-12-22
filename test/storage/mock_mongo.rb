# encoding: UTF-8

# A mock implementation of the Mongo::Connection class.
class MockMongo
  def initialize
    @collections = collections
  end

  def collection(name)
    @collections[name]
  end

  def clear
    @collections = collections
  end

  def collections
    {
      users: MockCollection.new,
      vcards: MockCollection.new,
      fragments: MockCollection.new
    }
  end

  class MockCollection
    def initialize
      @docs = {}
    end

    def find_one(doc)
      id = doc['_id'] || doc[:_id]
      @docs[id]
    end

    def save(doc, opts={})
      id = doc['_id'] || doc[:_id]
      @docs[id] = doc
    end
  end
end
