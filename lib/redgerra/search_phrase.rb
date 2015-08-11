# encoding: UTF-8
require 'strscan'
require 'object/in'
require 'web_search_result'
require 'web_search_error'
require 'random_accessible'
require 'set'

require 'open-uri'
require 'nokogiri'
require 'object/not_in'
require 'string/scrub'

module Redgerra
  
  # 
  # searches for phrases in Web which include +sloch+.
  # 
  # +web_search+ is a Proc which is passed with a query and +browser+,
  # passes the query to a web search engine and returns RandomAccessible
  # collection of WebSearchResult-s.
  # 
  # It may raise WebSearchError.
  # 
  def self.search_phrase(sloch, web_search, browser)
    #
    sloch_regexp = begin
      r = squeeze_whitespace(sloch).strip
      r = words_to_ids(r)
      r.gsub!("*", "#{WORD_ID}( ?,? ?#{WORD_ID})?")
      Regexp.new(r)
    end
    m = Memory.new
    # 
    web_search.(%("#{sloch}"), browser).
      lazy_cached_filter do |web_search_result|
        [web_search_result.page_excerpt]
      end.
      lazy_cached_filter do |text_block|
        text_block = squeeze_whitespace(text_block)
        text_block_parsed = words_to_ids(text_block)
        phrases_parsed = text_block_parsed.scan(/((#{WORD_ID}|[\,\-\ ])+)/o).map(&:first)
        phrases_parsed.
          map(&:strip).
          map { |phrase_parsed| [phrase_parsed, ids_to_words(phrase_parsed)] }.
          select do |phrase_parsed, phrase|
            phrase_downcase_parsed = words_to_ids(phrase.downcase)
            (
              m.not_mentioned_before?(phrase) and
              not upcase?(phrase) and
              word_ids(phrase_parsed).size <= 20 and
              sloch_regexp === phrase_downcase_parsed and
              # There must be at least 2 words before and after sloch.
              phrase_downcase_parsed.gsub(sloch, "|").split("|", -1).all? { |part| word_ids(part).size >= 2 }
            )
          end.
          map { |phrase_parsed, phrase| phrase }
      end
  end
  
  private
  
  class Text
    
    def self.parse(str)
      parsed_text = ""
      s = StringScanner.new(str)
      until s.eos?
        (abbr = s.scan(/[Ee]\. ?g\.|etc\.|i\. ?e\.|[Ss]mb\.|[Ss]mth\./) and act do
          parsed_text << Word.parse(abbr)
        end) or
        (word = s.scan(/#{word_chars = "[a-zA-Z0-9\\'\\$]+"}(\-#{word_chars})*/o) and act do
          parsed_text << Word.parse(word)
        end) or
        (other = s.getch and act do
          parsed_text << other
        end)
      end
      return Text.new(parsed_text)
    end
    
    def to_s
      text.gsub(/#{WORD_REGEXP}/o) { |parsed_word| to_word(parsed_word) }
    end
    
    # Accessible to Sloch only.
    def to_parsed_string
      @to_parsed_string
    end
    
    private
    
    def initialize(parsed_text)  # :nodoc:
      @parsed_text = parsed_text
    end
    
  end
  
  class Word
    
    # Accessible to Text, Sloch only.
    PARSED_REGEXP = "W[OX]\\h+W"
    
    # Accessible to Text only.
    def self.parse(word, is_proper_name_with_dot)
      parsed_word = "W#{is_proper_name_with_dot ? "O" : "X"}"
      word.each_codepoint do |code|
        raise "character code must be 00h–FFh: #{code}" unless code.in? 0x00..0xFF
        parsed_word << code.to_s(16)
      end
      parsed_word << "W"
      return Word.new(parsed_word)
    end
    
    private
    
    def initialize(parsed_word)  # :nodoc:
      @parsed_word = parsed_word
    end
    
    def to_s
      @parsed_word[2...-1].gsub(/\h\h/) { |code| code.hex.chr }
    end
    
  end
  
  class Sloch
    
    def self.parse(str)
      Sloch.new(
        Regexp.new(
          Text.parse(str).to_parsed_string.
            gsub("*", "#{Word::PARSED_REGEXP}( ?,? ?#{Word::PARSED_REGEXP})?")
        )
      )
    end
    
    private
    
    def initialize(regexp)  # :nodoc:
      @regexp = regexp
    end
    
  end
    
#   WORD_ID = "W\\h+W"
#   
#   # returns IDs from +str+.
#   # 
#   # +str+ is a String processed with ::words_to_ids().
#   # 
#   def self.word_ids(str)
#     str.scan(/#{WORD_ID}/o)
#   end
#   
#   # converts all consecutive white-space characters to " ".
#   def self.squeeze_whitespace(str)
#     str.gsub(/[\u0009-\u000D\u0020\u0085\u00A0\u1680\u180E\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+/, " ")
#   end
#   
#   def self.upcase?(word)
#     /[a-z]/ !~ word
#   end
#   
#   # 
#   # replaces words in +text+ with IDs. WORD_ID matches the IDs, it never
#   # matches anything else or a part of the ID.
#   # 
#   # +text+ must be #squeeze_whitespace()-ed.
#   # 
#   def self.words_to_ids(text)
#     # 
#     to_id = lambda do |word|
#       r = "W"
#       word.each_codepoint do |code|
#         raise "character code must be 00h–FFh: #{code}" unless code.in? 0x00..0xFF
#         r << code.to_s(16)
#       end
#       r << "W"
#       r
#     end
#     # Parse!
#     result = ""
#     s = StringScanner.new(text)
#     until s.eos?
#       (abbr = s.scan(/[Ee]\. ?g\.|etc\.|i\. ?e\.|[Ss]mb\.|[Ss]mth\./) and act do
#         result << to_id.(abbr)
#       end) or
#       (word = s.scan(/#{word_chars = "[a-zA-Z0-9\\'\\$]+"}(\-#{word_chars})*/o) and act do
#         result << to_id.(word)
#       end) or
#       (other = s.getch and act do
#         result << other
#       end)
#     end
#     return result
#   end
#   
#   # Inverse function of ::words_to_ids().
#   def self.ids_to_words(text)
#     text.gsub(/#{WORD_ID}/o) { |id| id[1...-1].gsub(/\h\h/) { |code| code.hex.chr } }
#   end
#   
#   # calls +f+ and returns true.
#   def self.act(&f)
#     f.()
#     return true
#   end
  
  # returns Array of String-s.
  def self.text_blocks_from_page_at(uri)
    #
    page_io =
      begin
        open(uri)
      rescue
        return []
      end
    #
    begin
      text_blocks_from(Nokogiri::HTML(page_io))
    ensure
      page_io.close()
    end
  end
  
  # returns Array of String's.
  # 
  # +element+ is Nokogiri::Element.
  # 
  def self.text_blocks_from(element)
    text_blocks = []
    start_new_text_block = lambda do
      text_blocks.push("") if text_blocks.empty? or not text_blocks.last.empty?
    end
    this = lambda do |element|
      case element
      when Nokogiri::XML::CDATA, Nokogiri::XML::Text
        text_blocks.last.concat(element.content.scrub("_"))
      when Nokogiri::XML::Comment
        # Do nothing.
      when Nokogiri::XML::Document, Nokogiri::XML::Element
        if element.name.in? %W{ script style } then
          start_new_text_block.()
        else
          element_is_separate_text_block = element.name.not_in? %W{
            a abbr acronym b bdi bdo br code del dfn em font i img ins kbd mark
            q s samp small span strike strong sub sup time tt u wbr
          }
          string_introduced_by_element =
            case element.name
            when "br" then "\n"
            when "img" then " "
            else ""
            end
          start_new_text_block.() if element_is_separate_text_block
          text_blocks.last.concat(string_introduced_by_element)
          element.children.each(&this)
          start_new_text_block.() if element_is_separate_text_block
        end
      else
        start_new_text_block.()
      end
    end
    this.(element)
    return text_blocks
  end

  class Memory
    
    def initialize()
      @impl = Set.new
    end
    
    # 
    # returns false once for every +x+. In other cases it returns true.
    # 
    def mentioned_before?(x)
      if @impl.include? x then
        @impl.add x
        return true
      else
        return false
      end
    end
    
    # Inversion of #mentioned_before?().
    def not_mentioned_before?(x)
      not mentioned_before?(x)
    end
    
  end
  
end


