#!/usr/bin/env ruby
# Ruby 2.1.0
# from here: https://github.com/jemmyw/Qif
require 'csv'
require 'qif'

# csv source file format:
#   [0] Date in dd/mm/yyyy,
#   [1] amount field,
#   [2] ignore,
#   [3] ignore,
#   [4] name
#   Ignore other fields
if !ARGV[0]
  raise ArgumentError, "Expected at least one csv file in arguments"
end

i = 0
j = 0
qif_file = "statements/output.qif"

Qif::Writer.open(qif_file, type = 'CCard', format = 'dd/mm/yyyy') do |qif|
  ARGV.each do |a|
    csv_file = a
    #basefile = csv_file.sub(/\.csv$/, '')
    bank_input = CSV.read(csv_file)
    puts "Converting #{csv_file} to QIF..."

    bank_input.each do |row|
      # Fix the values depending on what state your CSV data is in
      row.each { |value| value.to_s.gsub!(/^\s+|\s+$/,'') } # trim ends off each value
      row.each { |value| value.to_s.gsub!(/^"|"$/,'') } # trim quotes off each value
        
      qif << Qif::Transaction.new(
        :date         => row[0],
        :amount       => row[1],
        :payee         => row[4]
      )
      j += 1
    end # back_input.row
    i += 1
  end # ARGV.each
end # Qif::Writer.open

puts "Created #{qif_file} with #{j} transactions from #{i} csv files."
