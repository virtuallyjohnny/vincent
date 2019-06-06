require 'scraperwiki'
require 'mechanize'

url = "https://imagine.vincent.wa.gov.au/planning-consultations"

agent = Mechanize.new
page_number = 0
loop do
  page_number += 1
  page_url = "#{url}?page=#{page_number}"
  page = agent.get(page_url)

  puts "Parsing the results on page #{page_number}: #{page_url}"
  application_count = 0
  page.search('li.shared-content-block').each do |li|
    application_count += 1
    info_url = li.at('a')['href']
    details_page = agent.get(info_url)
    
    # Extract all text after "Serial Number:" from the second paragraph under the div which has class "truncated-description".
    council_reference = details_page.search('div.truncated-description p')[1].inner_text.gsub(/[\r\n]/, "").sub(/.*Serial Number:/, '').squeeze(' ').strip

    # Attempt to find a date.

    # Extract all text from the first <b>...</b> element under the div which has class "truncated-description" (and trim the trailing ".").
    possible_date_1_element = li.search('div.truncated-description b')[0]
    if (possible_date_1_element.nil?)
      possible_date_1_element = li.search('div.truncated-description strong')[0]
    end
    if (!possible_date_1_element.nil?)
      possible_date_1 = possible_date_1_element.inner_text.gsub(/[\r\n]/, "").squeeze(' ').strip.gsub(/\.$/, '')
    else
      possible_date_1 = ""
    end
    
    # Extract all text from the second <b>...</b> element under the div which has class "truncated-description" (and trim the trailing ".").
    possible_date_2_element = li.search('div.truncated-description b')[1]
    if (possible_date_2_element.nil?)
      possible_date_2_element = li.search('div.truncated-description string')[1]
    end
    if (!possible_date_2_element.nil?)
      possible_date_2 = possible_date_2_element.inner_text.gsub(/[\r\n]/, "").squeeze(' ').strip.gsub(/\.$/, '')
    else
      possible_date_2 = ""
    end
    
    matches_1 = possible_date_1.scan(/\b[0-9][0-9]?\s+[A-Z][A-Z][A-Z][A-Z]?\s+[0-9][0-9][0-9][0-9]$/i)
    matches_2 = possible_date_2.scan(/\b[0-9][0-9]?\s+[A-Z][A-Z][A-Z][A-Z]?\s+[0-9][0-9][0-9][0-9]$/i)
    parsed_date = ""
    if (matches_1.length >= 1)
      parsed_date = Date.parse(matches_1[0]).to_s
    elsif (matches_2.length >= 1)
      parsed_date = Date.parse(matches_2[0]).to_s
    end
    
    record = {
      'council_reference' => council_reference,
      'address' => li.at('a').inner_text.gsub("\r\n", "").squeeze(' ').strip,
      # Extract all text after "Development Details:" under the div which has class "truncated-description".
      'description' => li.at('div.truncated-description').inner_text.gsub(/[\r\n]/, "").sub(/.*Development Details:/, '').squeeze(' ').strip,
      'info_url' => info_url,
      'comment_url' => 'mailto:mail@vincent.wa.gov.au',
      'date_scraped' => Date.today.to_s,
      'on_notice_to' => parsed_date
    }
      
    puts "Saving page #{page_number} application record #{application_count}."
    puts "    council_reference: " + record['council_reference']
    puts "              address: " + record['address']
    puts "          description: " + record['description']
    puts "             info_url: " + record['info_url']
    puts "          comment_url: " + record['comment_url']
    puts "         date_scraped: " + record['date_scraped']
    puts "         on_notice_to: " + record['on_notice_to']
    ScraperWiki.save_sqlite(['council_reference'], record)
  end
  
  # Continue paging until a page is encountered with no applications (or, as a safety precaution, a large number of pages have been processed).
  puts "Found #{application_count} application(s) on page #{page_number}."
  break if application_count == 0 or page_number > 100
end
puts "Complete."
