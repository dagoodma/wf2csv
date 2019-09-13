require_relative 'pdf_parser'
require 'pp'

class Statement
  attr_accessor :statement_end_date, :account_number, :ending_balance, :starting_balance, :total_payments, :total_purchases, :total_credits, :total_advances, :total_fees, :total_interest, :payments, :purchases,:content
  
  MONTH="[01]\\d"
  #MONTHS="(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)"
  DAY="[0123]\\d"
  DATE="(#{MONTH}\/#{DAY})"
  DATE_YEAR="(#{MONTH}/#{DAY}/(20\\d\\d))" # MM/DD/YY[YY]
  AMOUNT="\$?((?:- )?(?:\\d{1,3},)?\\d{1,3}\\.\\d{2})"
  
#  AMOUNT="\s{5}((- )?[0123456789,]+\.[0123456789]{2})"
  
  def initialize(file_name)
    start_time = Time.now
    puts "Converting #{file_name}..."
    @content=PdfParser.new(file_name).content
    File.open("#{file_name}.txt",'w') {|f| f<<@content }
    @year=statement_end_date.split(/\//).last
    File.open("#{file_name}.csv",'w') do |f|
      all.each do |x|
        f.puts ["\"#{x["date"]}/#{@year}\"", "\"#{x["amount"]}\"", "\"*\"", "\"\"", "\"#{x["description"]}\""].join(",")
      end
    end
    start_time = Time.now
    unless audit?
      puts "***AUDIT file #{file_name}" 
      [:statement_end_date, :account_number, :starting_balance,:ending_balance, :calculated_ending_balance,  :total_payments, :calculated_total_payments, :total_purchases, :total_credits, :total_advances, :total_fees, :total_interest, :calculated_total_purchases].each do |field|
        puts "#{field.to_s}=#{self.send(field)}"
      end
      puts "#{calculated_ending_balance-ending_balance} missing!!!"
    end
    puts "Converted #{file_name} in #{format_elapsed_time(Time.now-start_time)} sec."
    puts "-----------------------------------------------------"
    if total_interest > 0
        exit
    end
  end
  
  def statement_end_date
    #puts "HERE!!!"
    #puts @content.class
    #puts /Previous/.match(@content)
    #puts /#{DATE_YEAR}\s*to\s*#{DATE_YEAR}/.match(@content)[2]
    @statement_end_date||=/#{DATE_YEAR}\s*to\s*#{DATE_YEAR}/.match(@content)[3]
    #@statement_end_date||=find_value(/#{DATE_YEAR}\s*to\s*#{DATE_YEAR}/)[1]
  end

  def starting_balance
    @starting_balance||=to_number(/Previous Balance \s* \$([^\s]+)/.match(@content)[1])
  end

  def ending_balance
    @ending_balance||=to_number(/New Balance \s* \$([^\s]+)/.match(@content)[1])
  end

  def account_number
    @account_number||=find_value(/Ending in\s*(\d+-?\d+)/)[0]
  end
  
  def total_payments
    @total_payments||=to_number(/Payments \s* \$([^\s]+)/.match(@content)[1])
  end
  
  def total_purchases
    @total_purchases||=-to_number(/Purchases, Balance Transfers & \s* \$([^\s]+)/.match(@content)[1])
  end
  
  def total_credits
    @total_credits||=to_number(/Other Credits \s* \$([^\s]+)/.match(@content)[1])
  end
  
  def total_advances
    @total_advances||=-to_number(/Cash Advances \s* \$([^\s]+)/.match(@content)[1])
  end
  
  def total_fees
    @total_fees||=-to_number(/Fees Charged \s* \$([^\s]+)/.match(@content)[1])
  end
  
  def total_interest
    @total_interest||=-to_number(/Interest Charged \s* \$([^\s]+)/.match(@content)[1])
  end
  
  
  def calculated_total_payments
    calculate_balance(payments)
  end
  
  def calculated_total_purchases
    calculate_balance(purchases)
  end
  
  def turnover
    calculated_total_payments+calculated_total_purchases+total_interest
  end
  
  def calculated_ending_balance
    truncate(starting_balance-turnover)
  end
  
  def audit?
    puts "Here with: #{calculated_ending_balance}===#{ending_balance}"
    calculated_ending_balance===ending_balance
  end

  def calculate_balance(txns)
    balance=txns.inject(0) do |balance,txn|
      balance+=txn["amount"]
      balance
    end
    truncate(balance)
  end
  
  def payments
    first = ! @payments
    @payments||=transactions(payments_section)
    if first
        puts "Read #{@payments.size} payments." end
    return @payments
  end
  
  def purchases
    first = ! @purchases
    @purchases||=transactions(purchases_section)
    
    if first
        # Make purchase amount negative
       @purchases.each_with_index { |x,i|
            x["amount"] *= -1
            @purchases[i] = x
        }
        puts "Read #{@purchases.size} purchases."
    end
    return @purchases
  end
  
  #def checks
  #  if has_checks?
  #    transactions(checks_section).collect{|x|[x[0],x[1],-x[2]]}
  #  else
  #    []
  #  end
  #end

  def interest
    date = statement_end_date.split(/\//)[0..-2].join("/")
    { "date" => date, "description" => "Total interest charged for this period", "amount" => total_interest }
  end
  
  def all
    if total_interest != 0
        (payments+purchases+[interest])
    else
        (payments+purchases)
    end
  end
  
  def transactions(text)
    if text.to_s.strip.empty?
      raise ArgumentError, "Expected text to read transactions from"
    end
    #           Trans       Post         Ref #            Desc   Amount
    text.scan(/#{DATE} \s* #{DATE} \s* ([0-9A-Za-z]+)? \s* (.*?) \s* #{AMOUNT}/).collect do |x|
      #pp x
      #pp x.size
      { "date" => x[1], "description" => x[3], "amount" => to_number(x[4]) }
    end
  end

  def balance_section
    @content[balance_start,rewards_start-balance_start]
  end

  def transactions_section
    if !news_start
      @content[transactions_start,interest_after_start-transactions_start]
    else
      @content[transactions_start,news_start-transactions_start]
    end
  end
  
  def payments_section
    @content[payments_start,purchases_start-payments_start]
  end

  def purchases_section
    #if has_checks?
    #  @content[purchases_start,checks_start-purchases_start]
    #else
    @content[purchases_start,interest_start-purchases_start]
  end

  def fees_section
    @content[fees_start,interest_start-fees_start]
  end

  def interest_section
    @content[interest_start,apr_start-interest_start]
  end

  #def checks_section
  #  @content[checks_start,balance_summary_start-checks_start]
  #end
  
  #def has_checks?
  #  checks_start!=nil
  #end
  
  def balance_summary_start
    @content.index "Balance Summary"
  end

  def rewards_start
    @content.index "Go Far Rewards Summary"
  end

  def transactions_start
    @content.index "Transactions"
  end

  def news_start
    @content.index "Wells Fargo News"
  end

  def interest_after_start
    interest_start2 = (@content[transactions_start..-1].index "Interest Charged") + transactions_start
    interest_and_after = @content[interest_start2..-1]
    next_page = interest_and_after.index "PAGE"
    after_start = next_page + interest_start2
    after_start
  end
 
  def payments_start
    (transactions_section.index "Payments") + transactions_start
  end

  def purchases_start
    (transactions_section.index "Purchases, Balance Transfers & Other Charges") + transactions_start
  end

  #def checks_start
  #  @content.index "CHECKS PAID"
  #end
  
  def fees_start
    (transactions_section.index "Fees Charged") + transactions_start
  end

  def interest_start
    (transactions_section.index "Interest Charged") + transactions_start
  end

  def apr_start
    (transactions_section.index "Interest Charge Calculation") + transactions_start
  end

  def to_number(amount)
    truncate(amount.gsub(/[ ,]/,'').to_f)
  end
  
  def truncate(number)
    ((((number*100).round).to_f)/100).to_f
  end
  
  def format_date(d)
    (d.split + [@year]).join('/')
  end

  def format_amount(a)
    a.strip.gsub(/,/,'').gsub(/\s+/,'')
    #  x[2] ? x[2].strip.gsub(/,/,' ').gsub(/\s+/,' ') : 'In branch check',to_number(x[3])]
  end

  def format_elapsed_time(dur)
    if dur === 0
        return "none"
    end
    conv = {
        "minutes" => 1/60,
        "seconds" => 1,
        "milliseconds" => 1e3,
        "microseconds" => 1e6,
        "nanoseconds" => 1e9
    }
    abbrev = {
        "minutes" => "m",
        "seconds" => "s",
        "milliseconds" => "ms",
        "microseconds" => "us",
        "nanoseconds" => "ns"
    }
    units = "minutes"
    if dur >= 60
        # Do nothing
    elsif dur >= 0.1
        units = "seconds";
    elsif dur >= 0.001
        units = "milliseconds";
    elsif dur >= 0.000001
        units = "microseconds";
    else 
        units = "nanoseconds";
    end

    dur *= conv[units]
    # TODO add abbrev as optional
    units = abbrev[units]
    return sprintf("%.3f %s", dur, units);
  end
  
  def to_hash
    attributes={}
    [:statement_end_date, :account_number, :ending_balance, :starting_balance, :total_payments, :total_purchases, :payments, :purchases].each do |name|
      attributes[name]=self.send(name)
    end
    attributes
  end
#  protected
  
  def search(regex)
    @content.scan(regex)
  end
  
  def find_value(regex)
    search(regex).first
  end
end
