class BulkRedirect
  # switch to ActiveModel::Model in Rails 4
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations

  attr_accessor :file

  def initialize(attributes = {})
    attributes.each { |name, value| send("#{name}=", value) }
  end

  def persisted?
    false
  end

  def save
    if bulk_redirects.map(&:valid?).all?
      bulk_redirects.each(&:save!)
      true
    else
      bulk_redirects.each_with_index do |work, index|
        work.errors.full_messages.each do |message|
          errors.add :base, "Row #{index+2}: #{message}"
        end
      end
      false
    end
  end

  def bulk_redirects
    @bulk_redirects ||= load_bulk_redirects
  end

  def load_bulk_redirects
    spreadsheet = open_spreadsheet
    header = spreadsheet.row(1)
    (2..spreadsheet.last_row).map do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      work = Work.find_by_id(row["id"])
      work.attributes = row.to_hash.slice(*Work.accessible_attributes)
      work
    end
  end

  def open_spreadsheet
    case File.extname(file.original_filename)
      when ".csv" then Csv.new(file.path, nil, :ignore)
      when ".xls" then Excel.new(file.path, nil, :ignore)
      when ".xlsx" then Excelx.new(file.path, nil, :ignore)
      else raise "Unknown file type: #{file.original_filename}"
    end
  end
end