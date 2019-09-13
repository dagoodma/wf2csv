#require 'pdf/reader'
require 'pdf-reader'

class PdfParser
  
  attr_accessor :content

  def initialize(file)
    content_io=StringIO.new
    reader   = PDF::Reader.new(file)
    reader.pages.each do |page|
      content_io << page.text
    end

    @content=content_io.string
  end
end
