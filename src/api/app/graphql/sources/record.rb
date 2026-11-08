module Sources
  # Loads records of one model by id, all ids of one resolution step in a single
  # query. Tenant models keep their workspace scope, because this runs inside it.
  class Record < GraphQL::Dataloader::Source
    def initialize(model, includes: nil)
      super()
      @model = model
      @includes = includes
    end

    def fetch(ids)
      scope = @includes ? @model.includes(@includes) : @model
      found = scope.where(id: ids).index_by(&:id)
      ids.map { |id| found[id] }
    end
  end
end
