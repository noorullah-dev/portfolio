# Minimal pagination for ActiveRecord relations.
#
# Replaces the kaminari-style `scope.page(n).per(k)` API with a small wrapper
# object that exposes `records`, `total_count`, `current_page`, `total_pages`
# and is Enumerable, so views can treat it like a relation or an array.
class PaginatedScope
  include Enumerable

  DEFAULT_PER_PAGE = 25

  attr_reader :records, :total_count, :current_page, :per_page

  def initialize(scope, page:, per_page: DEFAULT_PER_PAGE)
    @scope = scope
    @per_page = [per_page.to_i, 1].max
    @total_count = scope.except(:select, :order).count
    @total_pages = [(@total_count.to_f / @per_page).ceil, 1].max
    @current_page = page.to_i.clamp(1, @total_pages)
    @records = scope.limit(@per_page).offset((@current_page - 1) * @per_page).to_a
  end

  def each(&block)
    records.each(&block)
  end

  def size
    records.size
  end
  alias length size
  alias count size

  def empty?
    records.empty?
  end

  def total_pages
    @total_pages
  end

  def offset_value
    (current_page - 1) * per_page
  end

  def next_page
    current_page < total_pages ? current_page + 1 : nil
  end

  def prev_page
    current_page > 1 ? current_page - 1 : nil
  end
end

module Pageable
  private

  def paginate(scope, page: params[:page], per_page: self.class.try(:per_page) || PaginatedScope::DEFAULT_PER_PAGE)
    PaginatedScope.new(scope, page: page, per_page: per_page)
  end
end