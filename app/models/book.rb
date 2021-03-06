class Book < ApplicationRecord
  validates_presence_of :title

  has_many   :book_reviews
  has_many   :book_formats
  has_many   :book_format_types, through: :book_formats

  belongs_to :publisher
  belongs_to :author

  scope :title_only,     -> { pluck(:title) }
  scope :distinct_books, -> { select('DISTINCT books.*, AVG(book_reviews.rating)') }
  scope :by_rating,      -> { group('books.id').order('AVG(book_reviews.rating) DESC') }

  def author_name
    author.format_name
  end

  def average_rating
    (book_reviews.sum(:rating).to_f / book_reviews.count).round(1)
  end

  def self.search(query, options)
    return books_by_rating if !query && !options

    if !options
      query_lookup(query)
    elsif options.length == 2
      two_options_search_filter(query, options)
    else
      single_option_search_filter(query, options)
    end
  end

  private
  def self.single_option_search_filter(query, options)
    if options[:title_only]
      query_lookup(query).title_only
    elsif options[:book_format_type_id]
      query_lookup(query).book_format_type(options[:book_format_type_id])
    else
      query_lookup(query).book_format_physical(options[:book_format_physical])
    end
  end

  def self.two_options_search_filter(query, options)
    if !options[:book_format_type_id]
      query_lookup(query).book_format_physical(options[:book_format_physical]).title_only
    elsif !options[:book_format_physical]
      id = options[:book_format_type_id]
      query_lookup(query).book_format_type(id).title_only
    end
  end
  def self.query_lookup(query)
    search_by_title(query).length > 0 ? search_by_title(query) : search_by_author_name(query)
  end

  def self.search_by_title(query)
    books_by_rating.where("title LIKE ? ", "%#{query}%")
  end

  def self.search_by_author_name(query)
    books_by_rating.joins(:author).where("authors.first_name = ? OR authors.last_name = ?" , query, query)
  end

  def self.books_by_rating
    distinct_books
    .joins(:book_reviews)
    .by_rating
  end

  def self.book_format_type(id)
    distinct_books
    .joins(:book_format_types, :book_reviews)
    .merge(BookFormatType.format(id))
    .by_rating
  end

  def self.book_format_physical(boolean)
    distinct_books
    .joins(:book_format_types, :book_reviews)
    .merge(BookFormatType.physical(boolean))
    .by_rating
  end

end
