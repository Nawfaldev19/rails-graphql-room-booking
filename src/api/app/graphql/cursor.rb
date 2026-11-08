# Keyset ("cursor") paging over rows ordered by (created_at desc, id desc).
# Unlike OFFSET, a page costs the same wherever it is, and rows added while
# someone is paging do not shift later pages.
module Cursor
  MAX_PAGE = 50

  module_function

  def encode(record)
    Base64.urlsafe_encode64("#{record.created_at.utc.iso8601(6)}|#{record.id}", padding: false)
  end

  def decode(cursor)
    stamp, id = Base64.urlsafe_decode64(cursor.to_s).split("|")
    [ Time.iso8601(stamp), Integer(id) ]
  rescue ArgumentError
    raise ApiError.invalid("The paging cursor is not valid.")
  end

  def page(scope, first:, after: nil)
    raise ApiError.invalid("\"first\" must be between 1 and #{MAX_PAGE}.") unless first.between?(1, MAX_PAGE)

    if after.present?
      created_at, id = decode(after)
      scope = scope.where("created_at < :at OR (created_at = :at AND id < :id)", at: created_at, id:)
    end
    # One extra row tells whether another page exists. It is not returned.
    rows = scope.reorder(created_at: :desc, id: :desc).limit(first + 1).to_a
    items = rows.first(first)
    { items:, end_cursor: items.any? ? encode(items.last) : nil, has_next_page: rows.size > first }
  end
end
