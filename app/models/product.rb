class Product < ActiveRecord::Base
  attr_accessible :title, :imported_from
  
  validates_presence_of :price
  
  def self.to_csv(options = {})
    CSV.generate(options) do |csv|
      csv << column_names
      all.each do |product|
        csv << product.attributes.values_at(*column_names)
      end
    end
  end
end
