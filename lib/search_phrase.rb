# encoding: UTF-8
# require 'monitor'
# require 'object/not_in'
# require 'object/not_nil'
# require 'strscan'
# require 'random_accessible'
# require 'open-uri'
# require 'set'

require 'nokogiri'
require 'string/scrub'
require 'integer/chr_u'
require 'strscan'
require 'object/not_in'
require 'object/not_nil'
require 'object/not_empty'
require 'set'

# 
# Result of #search_phrase().
# 
# This class is thread-safe.
# 
class Phrases
  
#   include MonitorMixin
#   include RandomAccessible
#   
#   def initialize(phrase_part, urls, &need_stop)
#     super()
#     @urls = URLs.new(urls)
#     @phrase_part = squeeze_and_strip_whitespace(phrase_part).downcase
#     @cached_phrases = []
#     @cached_phrases_set = Set.new
#     @need_stop = need_stop || lambda { |url, phrase_found| false }
#     @search_stopped = false
#   end
#   
#   def initialize()
#   end
#   
#   # :call-seq:
#   #   phrases[i]
#   #   phrases[x..y]
#   # 
#   # In the first form it returns the phrase or nil if +i+ is out of range.
#   # In the second form it returns an Array of phrases (which may be empty
#   # if (x..y) is completely out or range).
#   # 
#   def [](arg)
#     mon_synchronize do
#       case arg
#       when Integer
#         i = arg
#         return get(i)
#       when Range
#         range = arg
#         result = []
#         for i in range
#           x = get(i)
#           result << x if x.not_nil?
#         end
#         return result
#       end
#     end
#   end
#   
#   # 
#   # returns either amount of these Phrases or :unknown.
#   # 
#   def size_u
#     mon_synchronize do
#       if @urls.current != nil and not @search_stopped then :unknown
#       else @cached_phrases.size
#       end
#     end
#   end
#   
# #   private
#   
#   def get(index)
#     while not @search_stopped and index >= @cached_phrases.size and @urls.current != nil
#       # 
#       page_io =
#         begin
#           open(@urls.current)
#         rescue
#           # Try the next URL (if present).
#           @urls.next!
#           if @urls.current.not_nil? then retry
#           else return nil
#           end
#         end
#       # 
#       begin
#         # Search for the phrases and puts them into @cached_phrases.
#         phrase_found = false
#         text_blocks_from(Nokogiri::HTML(page_io)).each do |text_block|
#           phrases_from(text_block).each do |phrase|
#             if phrase.downcase.include?(@phrase_part) and
#                 not @cached_phrases_set.include?(phrase) and
#                 phrase !~ /[\[\]\{\}]/ then
#               phrase_found = true
#               @cached_phrases.push phrase
#               @cached_phrases_set.add phrase
#             end
#           end
#         end
#         # Stop searching (if needed).
#         @search_stopped = @need_stop.(@urls.current, phrase_found)
#         break if @search_stopped
#         # 
#         @urls.next!
#       ensure
#         page_io.close()
#       end
#     end
#     # 
#     return @cached_phrases[index]
#   end
#   
#   def phrases_from1(url)
#     # 
#     page_io =
#       begin
#         open(url)
#       rescue
#         return []
#       end
#     #
#     begin
#       result = []
#       text_blocks_from(Nokogiri::HTML(page_io)).each do |text_block|
#         phrases_from(text_block).each do |phrase|
#           result.push(phrase)
#         end
#       end
#       return result
#     ensure
#       page_io.close()
#     end
#   end
#   
#   WHITESPACES_REGEXP_STRING = "[\u0009-\u000D\u0020\u0085\u00A0\u1680\u180E\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+"
#   WHITESPACES_REGEXP = /#{WHITESPACES_REGEXP_STRING}/
#   BORDERING_WHITESPACES_REGEXP = /^#{WHITESPACES_REGEXP_STRING}|#{WHITESPACES_REGEXP_STRING}$/
#   
#   # convers all consecutive white-space characters to " " and strips out
#   # bordering white space.
#   def squeeze_and_strip_whitespace(str)
#     str.
#       gsub(BORDERING_WHITESPACES_REGEXP, "").
#       gsub(WHITESPACES_REGEXP, " ")
#   end
#   
#   # returns phrases (Array of String's) from +str+. All phrases are processed
#   # with #squeeze_and_strip_whitespace().
#   def phrases_from(str)
#     str = str.gsub(WHITESPACES_REGEXP, " ")
#     phrases = [""]
#     s = StringScanner.new(str)
#     s.skip(/ /)
#     while not s.eos?
#       p = s.scan(/[\.\!\?…]+ /) and begin
#         p.chomp!(" ")
#         phrases.last.concat(p)
#         phrases.push("")
#       end
#       p = s.scan(/e\. ?g\.|etc\.|i\. ?e\.|smb\.|smth\.|./) and phrases.last.concat(p)
#     end
#     phrases.last.chomp!(" ")
#     phrases.pop() if phrases.last.empty?
#     phrases.shift() if not phrases.empty? and phrases.first.empty?
#     return phrases
#   end
#   
#   class URLs
#     
#     def initialize(urls)
#       @urls = urls
#       @current_index = 0
#     end
#     
#     def current
#       @urls[@current_index]
#     end
#     
#     def next!
#       @current_index += 1
#       nil
#     end
#     
#   end
  
  class CharSet
    
    def initialize()
      @char_ranges = []
    end
    
    # NOTE: It is optimized for monotonically increasing +char_code+-s.
    def add(char_code)
      char = char_code.chr_u
      if @char_ranges.empty? then
        @char_ranges.push(char..char)
        return
      end
      if @char_ranges.last.end.succ == char then
        @char_ranges[-1] = @char_ranges.last.begin..char
      else
        @char_ranges.push(char..char)
      end
    end
    
    # Returns regular expression (in the form of String) which matches this
    # CharSet.
    def to_regexp_str
      s = @char_ranges.map do |range|
        if range.begin == range.end then esc(range.begin)
        elsif range.begin.succ == range.end then "#{esc(range.begin)}#{esc(range.end)}"
        else "#{esc(range.begin)}-#{esc(range.end)}"
        end
      end
      "[#{s.join}]"
    end
    
    # Regular expression (in the form of String) which matches any character
    # from +category+ from +section+ (the sections are in this file, after
    # "__END__" keyword). If the category is +:any+ then all characters from
    # the section are selected.
    # 
    # The categories from the same section never overlap.
    # 
    def self.regexp_str(category, section = "Character categories")
      required_category = category
      r = CharSet.new
      DATA.rewind()
      until /^Section "#{section}"/ === DATA.gets; end
      DATA.each_line do |line|
        break if /^End Section/ === line
        line.gsub!(/\#.*$/, "") # Remove comments.
        line.strip!
        next if line.empty?
        char_code, category = line.split(/\s+/, 2)
        next unless required_category == :any or category == required_category
        char_code = char_code[/U+(.*)/, 1].to_i(16)
        r.add(char_code)
      end
      return r.to_regexp_str
    end
    
    private
    
    def escape_special_regexp_char(char)
      if char.in? "!\"#$%&'()*+,-./:;<=>?@[\\]^`~" then "\\#{char}"
      else char
      end
    end
    
    alias esc escape_special_regexp_char
    
    public
    
  end
  
  class Phrase
    
    def initialize()
      @str = ""
      @include_other_chars = false
      @forbidden_char_pos = nil
    end
    
    # Set #include_other_chars? to true.
    def include_other_chars!
      @include_other_chars = true
    end
    
    # Does this Phrase include characters from "Other" set (diacritics,
    # math. operators etc.)?
    # 
    # Initially it is false.
    # 
    def include_other_chars?
      @include_other_chars
    end
    
    # Forbidden character position (if any). It may be nil.
    attr_accessor :forbidden_char_pos
    
    def concat(str)
      @str.concat(str)
    end
    
    def empty?
      @str.empty?
    end
    
    def chomp!(suffix)
      @str.chomp!(suffix)
    end
    
    def length
      @str.length
    end
    
    alias << concat
    
    def to_s
      @str
    end
    
    def inspect
      %(#{@str.inspect} (#{if include_other_chars? then "!" else "_" end} #{forbidden_char_pos or "_"}))
    end
    
  end
  
  # returns Array of String's.
  def text_blocks_from(element)
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
  
  SENTENCE_END_PUNCTUATION = CharSet.regexp_str("SENTENCE END PUNCTUATION")
  IN_SENTENCE_PUNCTUATION = CharSet.regexp_str("IN-SENTENCE PUNCTUATION")
  LETTER_OR_DIGIT = CharSet.regexp_str("LETTER OR DIGIT")
  HYPHEN = CharSet.regexp_str("HYPHEN")
  WHITESPACE = CharSet.regexp_str("WHITESPACE")
  FORBIDDEN_CHAR = CharSet.regexp_str(:any, "Forbidden characters")
  
  WORD = "([Ee]\\. ?g\\.|etc\\.|i\\. ?e\\.|[Ss]mb\\.|[Ss]mth\\.|(#{LETTER_OR_DIGIT}+(#{HYPHEN}+#{LETTER_OR_DIGIT}+)*))"
  
  # Returns all phrases from +str+ (in the form of Array of Phrase-s). All
  # whitespaces in the phrases are squeezed and converted to " ".
  def phrases_from(str)
    # 
    str.gsub!(/#{WHITESPACE}+/, " ")
    # Parsing DSL.
    phrases = [Phrase.new]
    s = StringScanner.new(str)
    current_phrase = lambda { phrases.last }
    phrase_continued = lambda { |str| current_phrase.().concat(str) }
    phrase_end = lambda { phrases.push Phrase.new }
    other_chars_included = lambda { current_phrase.().include_other_chars! }
    before_forbidden_char = lambda { current_phrase.().forbidden_char_pos ||= current_phrase.().length }
    debug = lambda { |msg| puts msg; true }
    # Parse!
    s.skip(/ /)
    loop do
      (
        s.eos? and
          break
      ) or
      (
        x = s.scan(/#{SENTENCE_END_PUNCTUATION}+/) and s.skip(/ ?/) and act do
          phrase_continued.(x)
          phrase_end.()
        end
      ) or
      (
        x = s.scan(/#{WORD}| /) and act do
          phrase_continued.(x)
        end
      ) or
      (
        x = s.scan(/#{IN_SENTENCE_PUNCTUATION}|#{HYPHEN}/) and act do
          if /#{FORBIDDEN_CHAR}/ === x then before_forbidden_char.() end
          phrase_continued.(x)
        end
      ) or
      (
        x = s.getch() and act do
          other_chars_included.()
          phrase_continued.(x)
        end
      )
    end
    phrases.pop() if phrases.not_empty? and phrases.last.empty?
    # 
    return phrases
  end
  
  # Calls +f+ and returns true.
  def act(&f)
    f.()
    true
  end
  
  # Does +phrase+ (Phrase) fit Redgerra's requirements?
  # 
  # This method is not idempotent, it also returns false on "duplicate" phrases
  # (as specified by Redgerra).
  # 
  def fits?(phrase)
    #
    return false if phrase.include_other_chars?
    # 
    return false if /\[\]\{\}/ === phrase.to_s  # TODO: Is it correct?
    #
    downcase_phrase = phrase.to_s.downcase
    phrase_part_pos = (@phrase_part_regexp =~ downcase_phrase)
    return false unless phrase_part_pos
    # Duplicate check.
    if phrase.forbidden_char_pos and phrase_part_pos < phrase.forbidden_char_pos then
      mentioned_before? downcase_phrase[0...phrase.forbidden_char_pos]
    else
      mentioned_before? downcase_phrase
    end
  end
  
  # 
  # Returns true for any +obj+ only once.
  # 
  # Example:
  # 
  #   mentioned_before? "blah"  #=> true
  #   mentioned_before? "blah"  #=> false
  #   mentioned_before? "yup"   #=> true
  # 
  def mentioned_before?(obj)
    if @mentioned_before_memory.include? obj then
      return false
    else
      @mentioned_before_memory.add obj
      return true
    end
  end
  
  def initialize(phrase_part)
    @phrase_part_regexp = Regexp.new(
      phrase_part.
        downcase.
        gsub(/#{WHITESPACE}+/, " ").strip.
        split("*").map { |part| Regexp.escape(part) }.join("*").
        gsub("*", "#{WORD}(( ?,? ?)#{WORD})?")
    )
    @mentioned_before_memory = Set.new
  end
  
end

def phrase_from(str)
  Phrases.new('').phrases_from(str).first.tap { |x| p x }
end

h = Phrases.new("    do *   flop     ")
p h.fits?(phrase_from("Everybody do the, flop!"))
p h.fits?(phrase_from("Everybody do the flop it - first"))
p h.fits?(phrase_from("Everybody do the flop it - second"))
p h.fits?(phrase_from("Everybody - do the flop"))
p h.fits?(phrase_from("Everybody - do the flop"))
p h.fits?(phrase_from("Everybody - do the flop!"))
exit
p Phrases.new('').phrases_from <<TEXT
Everybody  do    the flop!!! Do the flop   — do the flop!
Do the flop - do the flop-flop-flop!
Everybody, do the  flop.
Everybody should sing "do-the-flop"! And smb. should definitely sing "do-the-flop"!
Very bad © phrase
TEXT
p Phrases.new('').phrases_from ""

# p Phrases.new.phrases_from1("https://en.wikipedia.org/wiki/2013_Rosario_gas_explosion");

# 
# searches for phrases in pages located at specified URL's and returns Phrases.
# Phrases containing "{", "}", "[" or "]" are omitted.
# 
# +phrase_part+ is a part of phrases being searched for.
# 
# +urls+ is a RandomAccessible of URL's.
# 
# +need_stop+ is passed with an URL and +phrase_found+ (which is true
# if the specified phrase if found at the URL and false otherwise). It must
# return true if the searching must be stopped immediately (and no more +urls+
# should be inspected) and false otherwise. It is optional, default is to
# always return false.
# 
def search_phrase(phrase_part, urls, &need_stop)
  return Phrases.new(phrase_part, urls, &need_stop)
end

__END__

# 
# Keep sections below sorted, otherwise optimization in CharSet#add() will not
# be used! You may use following script to sort them:
# 
# DATA.read.lines.sort_by { |l| (l[/U\+([^ ]+)/, 1] || "").to_i(16) }.
#   each { |l| puts l }
# 

Section "Character categories"

# TODO: Use public references to mark categories "SENTENCE END PUNCTUATION" and
#   "IN-SENTENCE PUNCTUATION".

# TODO: See commit 90ae0df9b2f275a9cab0f946dbaa3c11a224e8df.

U+0009  WHITESPACE  # CHARACTER TABULATION
U+000A  WHITESPACE  # LINE FEED (LF)
U+000B  WHITESPACE  # LINE TABULATION         
U+000C  WHITESPACE  # FORM FEED (FF)  
U+000D  WHITESPACE  # CARRIAGE RETURN (CR)
U+0020  WHITESPACE  # SPACE
U+0021  SENTENCE END PUNCTUATION  # EXCLAMATION MARK        !
U+0022  IN-SENTENCE PUNCTUATION  # QUOTATION MARK  "
U+0023  IN-SENTENCE PUNCTUATION  # NUMBER SIGN     #
U+0024  LETTER OR DIGIT  # DOLLAR SIGN     $
U+0025  IN-SENTENCE PUNCTUATION  # PERCENT SIGN    %
U+0026  IN-SENTENCE PUNCTUATION  # AMPERSAND       &
U+0027  LETTER OR DIGIT  # APOSTROPHE      '     # In words like “let's“.
U+0028  IN-SENTENCE PUNCTUATION  # LEFT PARENTHESIS        (
U+0029  IN-SENTENCE PUNCTUATION  # RIGHT PARENTHESIS       )
U+002A  IN-SENTENCE PUNCTUATION  # ASTERISK        *
U+002B  IN-SENTENCE PUNCTUATION  # PLUS SIGN    +
U+002C  IN-SENTENCE PUNCTUATION  # COMMA   ,
U+002D  HYPHEN  # HYPHEN-MINUS    -
U+002E  SENTENCE END PUNCTUATION  # FULL STOP       .
U+002F  IN-SENTENCE PUNCTUATION  # SOLIDUS         /
U+0030  LETTER OR DIGIT  # DIGIT ZERO      0
U+0031  LETTER OR DIGIT  # DIGIT ONE       1
U+0032  LETTER OR DIGIT  # DIGIT TWO       2
U+0033  LETTER OR DIGIT  # DIGIT THREE     3
U+0034  LETTER OR DIGIT  # DIGIT FOUR      4
U+0035  LETTER OR DIGIT  # DIGIT FIVE      5
U+0036  LETTER OR DIGIT  # DIGIT SIX       6
U+0037  LETTER OR DIGIT  # DIGIT SEVEN     7
U+0038  LETTER OR DIGIT  # DIGIT EIGHT     8
U+0039  LETTER OR DIGIT  # DIGIT NINE      9
U+003A  IN-SENTENCE PUNCTUATION  # COLON   :
U+003B  IN-SENTENCE PUNCTUATION  # SEMICOLON       ;
U+003C  IN-SENTENCE PUNCTUATION  # LESS-THAN SIGN  <
U+003D  IN-SENTENCE PUNCTUATION  # EQUALS SIGN     =
U+003E  IN-SENTENCE PUNCTUATION  # GREATER-THAN SIGN       >
U+003F  SENTENCE END PUNCTUATION  # QUESTION MARK   ?
U+0040  IN-SENTENCE PUNCTUATION  # COMMERCIAL AT   @
U+0041  LETTER OR DIGIT  # LATIN CAPITAL LETTER A  A
U+0042  LETTER OR DIGIT  # LATIN CAPITAL LETTER B  B
U+0043  LETTER OR DIGIT  # LATIN CAPITAL LETTER C  C
U+0044  LETTER OR DIGIT  # LATIN CAPITAL LETTER D  D
U+0045  LETTER OR DIGIT  # LATIN CAPITAL LETTER E  E
U+0046  LETTER OR DIGIT  # LATIN CAPITAL LETTER F  F
U+0047  LETTER OR DIGIT  # LATIN CAPITAL LETTER G  G
U+0048  LETTER OR DIGIT  # LATIN CAPITAL LETTER H  H
U+0049  LETTER OR DIGIT  # LATIN CAPITAL LETTER I  I
U+004A  LETTER OR DIGIT  # LATIN CAPITAL LETTER J  J
U+004B  LETTER OR DIGIT  # LATIN CAPITAL LETTER K  K
U+004C  LETTER OR DIGIT  # LATIN CAPITAL LETTER L  L
U+004D  LETTER OR DIGIT  # LATIN CAPITAL LETTER M  M
U+004E  LETTER OR DIGIT  # LATIN CAPITAL LETTER N  N
U+004F  LETTER OR DIGIT  # LATIN CAPITAL LETTER O  O
U+0050  LETTER OR DIGIT  # LATIN CAPITAL LETTER P  P
U+0051  LETTER OR DIGIT  # LATIN CAPITAL LETTER Q  Q
U+0052  LETTER OR DIGIT  # LATIN CAPITAL LETTER R  R
U+0053  LETTER OR DIGIT  # LATIN CAPITAL LETTER S  S
U+0054  LETTER OR DIGIT  # LATIN CAPITAL LETTER T  T
U+0055  LETTER OR DIGIT  # LATIN CAPITAL LETTER U  U
U+0056  LETTER OR DIGIT  # LATIN CAPITAL LETTER V  V
U+0057  LETTER OR DIGIT  # LATIN CAPITAL LETTER W  W
U+0058  LETTER OR DIGIT  # LATIN CAPITAL LETTER X  X
U+0059  LETTER OR DIGIT  # LATIN CAPITAL LETTER Y  Y
U+005A  LETTER OR DIGIT  # LATIN CAPITAL LETTER Z  Z
U+005B  IN-SENTENCE PUNCTUATION  # LEFT SQUARE BRACKET     [
U+005C  IN-SENTENCE PUNCTUATION  # REVERSE SOLIDUS         \
U+005D  IN-SENTENCE PUNCTUATION  # RIGHT SQUARE BRACKET    ]
U+005E  IN-SENTENCE PUNCTUATION  # CIRCUMFLEX ACCENT    ^
U+005F  IN-SENTENCE PUNCTUATION  # LOW LINE        _
U+0060  IN-SENTENCE PUNCTUATION  # GRAVE ACCENT    `
U+0061  LETTER OR DIGIT  # LATIN SMALL LETTER A    a
U+0062  LETTER OR DIGIT  # LATIN SMALL LETTER B    b
U+0063  LETTER OR DIGIT  # LATIN SMALL LETTER C    c
U+0064  LETTER OR DIGIT  # LATIN SMALL LETTER D    d
U+0065  LETTER OR DIGIT  # LATIN SMALL LETTER E    e
U+0066  LETTER OR DIGIT  # LATIN SMALL LETTER F    f
U+0067  LETTER OR DIGIT  # LATIN SMALL LETTER G    g
U+0068  LETTER OR DIGIT  # LATIN SMALL LETTER H    h
U+0069  LETTER OR DIGIT  # LATIN SMALL LETTER I    i
U+006A  LETTER OR DIGIT  # LATIN SMALL LETTER J    j
U+006B  LETTER OR DIGIT  # LATIN SMALL LETTER K    k
U+006C  LETTER OR DIGIT  # LATIN SMALL LETTER L    l
U+006D  LETTER OR DIGIT  # LATIN SMALL LETTER M    m
U+006E  LETTER OR DIGIT  # LATIN SMALL LETTER N    n
U+006F  LETTER OR DIGIT  # LATIN SMALL LETTER O    o
U+0070  LETTER OR DIGIT  # LATIN SMALL LETTER P    p
U+0071  LETTER OR DIGIT  # LATIN SMALL LETTER Q    q
U+0072  LETTER OR DIGIT  # LATIN SMALL LETTER R    r
U+0073  LETTER OR DIGIT  # LATIN SMALL LETTER S    s
U+0074  LETTER OR DIGIT  # LATIN SMALL LETTER T    t
U+0075  LETTER OR DIGIT  # LATIN SMALL LETTER U    u
U+0076  LETTER OR DIGIT  # LATIN SMALL LETTER V    v
U+0077  LETTER OR DIGIT  # LATIN SMALL LETTER W    w
U+0078  LETTER OR DIGIT  # LATIN SMALL LETTER X    x
U+0079  LETTER OR DIGIT  # LATIN SMALL LETTER Y    y
U+007A  LETTER OR DIGIT  # LATIN SMALL LETTER Z    z
U+007B  IN-SENTENCE PUNCTUATION  # LEFT CURLY BRACKET      {
U+007C  IN-SENTENCE PUNCTUATION  # VERTICAL LINE   |
U+007D  IN-SENTENCE PUNCTUATION  # RIGHT CURLY BRACKET     }
U+007E  IN-SENTENCE PUNCTUATION  # TILDE      ~
U+0085  WHITESPACE  # NEXT LINE (NEL)         …
U+00A0  WHITESPACE  # NO-BREAK SPACE
U+00A1  IN-SENTENCE PUNCTUATION  # INVERTED EXCLAMATION MARK       ¡
U+00A7  IN-SENTENCE PUNCTUATION  # SECTION SIGN    §
U+00AB  IN-SENTENCE PUNCTUATION  # LEFT-POINTING DOUBLE ANGLE QUOTATION MARK       «
U+00B6  IN-SENTENCE PUNCTUATION  # PILCROW SIGN    ¶
U+00B7  IN-SENTENCE PUNCTUATION  # MIDDLE DOT      ·
U+00BB  IN-SENTENCE PUNCTUATION  # RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK      »
U+00BF  IN-SENTENCE PUNCTUATION  # INVERTED QUESTION MARK  ¿
U+037E  IN-SENTENCE PUNCTUATION  # GREEK QUESTION MARK     ;
U+0387  IN-SENTENCE PUNCTUATION  # GREEK ANO TELEIA        ·
U+055A  LETTER OR DIGIT  # ARMENIAN APOSTROPHE     ՚     # In words like “let's“.
U+055B  IN-SENTENCE PUNCTUATION  # ARMENIAN EMPHASIS MARK  ՛
U+055C  SENTENCE END PUNCTUATION  # ARMENIAN EXCLAMATION MARK       ՜
U+055D  IN-SENTENCE PUNCTUATION  # ARMENIAN COMMA  ՝
U+055E  SENTENCE END PUNCTUATION  # ARMENIAN QUESTION MARK  ՞
U+055F  IN-SENTENCE PUNCTUATION  # ARMENIAN ABBREVIATION MARK      ՟
U+0589  SENTENCE END PUNCTUATION  # ARMENIAN FULL STOP      ։
U+058A  HYPHEN  # ARMENIAN HYPHEN         ֊
U+05BE  IN-SENTENCE PUNCTUATION  # HEBREW PUNCTUATION MAQAF        ־
U+05C0  IN-SENTENCE PUNCTUATION  # HEBREW PUNCTUATION PASEQ        ׀
U+05C3  IN-SENTENCE PUNCTUATION  # HEBREW PUNCTUATION SOF PASUQ    ׃
U+05C6  IN-SENTENCE PUNCTUATION  # HEBREW PUNCTUATION NUN HAFUKHA  ׆
U+05F3  IN-SENTENCE PUNCTUATION  # HEBREW PUNCTUATION GERESH       ׳
U+05F4  IN-SENTENCE PUNCTUATION  # HEBREW PUNCTUATION GERSHAYIM    ״
U+0609  IN-SENTENCE PUNCTUATION  # ARABIC-INDIC PER MILLE SIGN     ؉
U+060A  IN-SENTENCE PUNCTUATION  # ARABIC-INDIC PER TEN THOUSAND SIGN      ؊
U+060C  IN-SENTENCE PUNCTUATION  # ARABIC COMMA    ،
U+060D  IN-SENTENCE PUNCTUATION  # ARABIC DATE SEPARATOR   ؍
U+061B  IN-SENTENCE PUNCTUATION  # ARABIC SEMICOLON        ؛
U+061E  IN-SENTENCE PUNCTUATION  # ARABIC TRIPLE DOT PUNCTUATION MARK      ؞
U+061F  SENTENCE END PUNCTUATION  # ARABIC QUESTION MARK    ؟
U+066A  IN-SENTENCE PUNCTUATION  # ARABIC PERCENT SIGN     ٪
U+066B  IN-SENTENCE PUNCTUATION  # ARABIC DECIMAL SEPARATOR        ٫
U+066C  IN-SENTENCE PUNCTUATION  # ARABIC THOUSANDS SEPARATOR      ٬
U+066D  IN-SENTENCE PUNCTUATION  # ARABIC FIVE POINTED STAR        ٭
U+06D4  SENTENCE END PUNCTUATION  # ARABIC FULL STOP        ۔
U+0700  SENTENCE END PUNCTUATION  # SYRIAC END OF PARAGRAPH         ܀
U+0701  SENTENCE END PUNCTUATION  # SYRIAC SUPRALINEAR FULL STOP    ܁
U+0702  SENTENCE END PUNCTUATION  # SYRIAC SUBLINEAR FULL STOP      ܂
U+0703  IN-SENTENCE PUNCTUATION  # SYRIAC SUPRALINEAR COLON        ܃
U+0704  IN-SENTENCE PUNCTUATION  # SYRIAC SUBLINEAR COLON  ܄
U+0705  IN-SENTENCE PUNCTUATION  # SYRIAC HORIZONTAL COLON         ܅
U+0706  IN-SENTENCE PUNCTUATION  # SYRIAC COLON SKEWED LEFT        ܆
U+0707  IN-SENTENCE PUNCTUATION  # SYRIAC COLON SKEWED RIGHT       ܇
U+0708  IN-SENTENCE PUNCTUATION  # SYRIAC SUPRALINEAR COLON SKEWED LEFT    ܈
U+0709  IN-SENTENCE PUNCTUATION  # SYRIAC SUBLINEAR COLON SKEWED RIGHT     ܉
U+070A  IN-SENTENCE PUNCTUATION  # SYRIAC CONTRACTION      ܊
U+070B  IN-SENTENCE PUNCTUATION  # SYRIAC HARKLEAN OBELUS  ܋
U+070C  IN-SENTENCE PUNCTUATION  # SYRIAC HARKLEAN METOBELUS       ܌
U+070D  IN-SENTENCE PUNCTUATION  # SYRIAC HARKLEAN ASTERISCUS      ܍
U+07F7  IN-SENTENCE PUNCTUATION  # NKO SYMBOL GBAKURUNEN   ߷
U+07F8  IN-SENTENCE PUNCTUATION  # NKO COMMA       ߸
U+07F9  IN-SENTENCE PUNCTUATION  # NKO EXCLAMATION MARK    ߹
U+0830  IN-SENTENCE PUNCTUATION  # SAMARITAN PUNCTUATION NEQUDAA   ࠰
U+0831  IN-SENTENCE PUNCTUATION  # SAMARITAN PUNCTUATION AFSAAQ    ࠱
U+0832  IN-SENTENCE PUNCTUATION  # SAMARITAN PUNCTUATION ANGED     ࠲
U+0833  IN-SENTENCE PUNCTUATION  # SAMARITAN PUNCTUATION BAU       ࠳
U+0834  IN-SENTENCE PUNCTUATION  # SAMARITAN PUNCTUATION ATMAAU    ࠴
U+0835  IN-SENTENCE PUNCTUATION  # SAMARITAN PUNCTUATION SHIYYAALAA        ࠵
U+0836  IN-SENTENCE PUNCTUATION  # SAMARITAN ABBREVIATION MARK     ࠶
U+0837  IN-SENTENCE PUNCTUATION  # SAMARITAN PUNCTUATION MELODIC QITSA     ࠷
U+0838  IN-SENTENCE PUNCTUATION  # SAMARITAN PUNCTUATION ZIQAA     ࠸
U+0839  IN-SENTENCE PUNCTUATION  # SAMARITAN PUNCTUATION QITSA     ࠹
U+083A  IN-SENTENCE PUNCTUATION  # SAMARITAN PUNCTUATION ZAEF      ࠺
U+083B  IN-SENTENCE PUNCTUATION  # SAMARITAN PUNCTUATION TURU      ࠻
U+083C  IN-SENTENCE PUNCTUATION  # SAMARITAN PUNCTUATION ARKAANU   ࠼
U+083D  IN-SENTENCE PUNCTUATION  # SAMARITAN PUNCTUATION SOF MASHFAAT      ࠽
U+083E  IN-SENTENCE PUNCTUATION  # SAMARITAN PUNCTUATION ANNAAU    ࠾
U+085E  IN-SENTENCE PUNCTUATION  # MANDAIC PUNCTUATION     ࡞
U+0964  IN-SENTENCE PUNCTUATION  # DEVANAGARI DANDA        ।
U+0965  IN-SENTENCE PUNCTUATION  # DEVANAGARI DOUBLE DANDA         ॥
U+0970  IN-SENTENCE PUNCTUATION  # DEVANAGARI ABBREVIATION SIGN    ॰
U+0AF0  IN-SENTENCE PUNCTUATION  # GUJARATI ABBREVIATION SIGN      ૰
U+0DF4  IN-SENTENCE PUNCTUATION  # SINHALA PUNCTUATION KUNDDALIYA  ෴
U+0E4F  IN-SENTENCE PUNCTUATION  # THAI CHARACTER FONGMAN  ๏
U+0E5A  IN-SENTENCE PUNCTUATION  # THAI CHARACTER ANGKHANKHU       ๚
U+0E5B  IN-SENTENCE PUNCTUATION  # THAI CHARACTER KHOMUT   ๛
U+0F04  IN-SENTENCE PUNCTUATION  # TIBETAN MARK INITIAL YIG MGO MDUN MA    ༄
U+0F05  IN-SENTENCE PUNCTUATION  # TIBETAN MARK CLOSING YIG MGO SGAB MA    ༅
U+0F06  IN-SENTENCE PUNCTUATION  # TIBETAN MARK CARET YIG MGO PHUR SHAD MA         ༆
U+0F07  IN-SENTENCE PUNCTUATION  # TIBETAN MARK YIG MGO TSHEG SHAD MA      ༇
U+0F08  IN-SENTENCE PUNCTUATION  # TIBETAN MARK SBRUL SHAD         ༈
U+0F09  IN-SENTENCE PUNCTUATION  # TIBETAN MARK BSKUR YIG MGO      ༉
U+0F0A  IN-SENTENCE PUNCTUATION  # TIBETAN MARK BKA- SHOG YIG MGO  ༊
U+0F0B  IN-SENTENCE PUNCTUATION  # TIBETAN MARK INTERSYLLABIC TSHEG        ་
U+0F0C  IN-SENTENCE PUNCTUATION  # TIBETAN MARK DELIMITER TSHEG BSTAR      ༌
U+0F0D  IN-SENTENCE PUNCTUATION  # TIBETAN MARK SHAD       །
U+0F0E  IN-SENTENCE PUNCTUATION  # TIBETAN MARK NYIS SHAD  ༎
U+0F0F  IN-SENTENCE PUNCTUATION  # TIBETAN MARK TSHEG SHAD         ༏
U+0F10  IN-SENTENCE PUNCTUATION  # TIBETAN MARK NYIS TSHEG SHAD    ༐
U+0F11  IN-SENTENCE PUNCTUATION  # TIBETAN MARK RIN CHEN SPUNGS SHAD       ༑
U+0F12  IN-SENTENCE PUNCTUATION  # TIBETAN MARK RGYA GRAM SHAD     ༒
U+0F14  IN-SENTENCE PUNCTUATION  # TIBETAN MARK GTER TSHEG         ༔
U+0F3A  IN-SENTENCE PUNCTUATION  # TIBETAN MARK GUG RTAGS GYON     ༺
U+0F3B  IN-SENTENCE PUNCTUATION  # TIBETAN MARK GUG RTAGS GYAS     ༻
U+0F3C  IN-SENTENCE PUNCTUATION  # TIBETAN MARK ANG KHANG GYON     ༼
U+0F3D  IN-SENTENCE PUNCTUATION  # TIBETAN MARK ANG KHANG GYAS     ༽
U+0F85  IN-SENTENCE PUNCTUATION  # TIBETAN MARK PALUTA     ྅
U+0FD0  IN-SENTENCE PUNCTUATION  # TIBETAN MARK BSKA- SHOG GI MGO RGYAN    ࿐
U+0FD1  IN-SENTENCE PUNCTUATION  # TIBETAN MARK MNYAM YIG GI MGO RGYAN     ࿑
U+0FD2  IN-SENTENCE PUNCTUATION  # TIBETAN MARK NYIS TSHEG         ࿒
U+0FD3  IN-SENTENCE PUNCTUATION  # TIBETAN MARK INITIAL BRDA RNYING YIG MGO MDUN MA        ࿓
U+0FD4  IN-SENTENCE PUNCTUATION  # TIBETAN MARK CLOSING BRDA RNYING YIG MGO SGAB MA        ࿔
U+0FD9  IN-SENTENCE PUNCTUATION  # TIBETAN MARK LEADING MCHAN RTAGS        ࿙
U+0FDA  IN-SENTENCE PUNCTUATION  # TIBETAN MARK TRAILING MCHAN RTAGS       ࿚
U+104A  IN-SENTENCE PUNCTUATION  # MYANMAR SIGN LITTLE SECTION     ၊
U+104B  IN-SENTENCE PUNCTUATION  # MYANMAR SIGN SECTION    ။
U+104C  IN-SENTENCE PUNCTUATION  # MYANMAR SYMBOL LOCATIVE         ၌
U+104D  IN-SENTENCE PUNCTUATION  # MYANMAR SYMBOL COMPLETED        ၍
U+104E  IN-SENTENCE PUNCTUATION  # MYANMAR SYMBOL AFOREMENTIONED   ၎
U+104F  IN-SENTENCE PUNCTUATION  # MYANMAR SYMBOL GENITIVE         ၏
U+10FB  IN-SENTENCE PUNCTUATION  # GEORGIAN PARAGRAPH SEPARATOR    ჻
U+1360  IN-SENTENCE PUNCTUATION  # ETHIOPIC SECTION MARK   ፠
U+1361  IN-SENTENCE PUNCTUATION  # ETHIOPIC WORDSPACE      ፡
U+1362  SENTENCE END PUNCTUATION  # ETHIOPIC FULL STOP      ።
U+1363  IN-SENTENCE PUNCTUATION  # ETHIOPIC COMMA  ፣
U+1364  IN-SENTENCE PUNCTUATION  # ETHIOPIC SEMICOLON      ፤
U+1365  IN-SENTENCE PUNCTUATION  # ETHIOPIC COLON  ፥
U+1366  IN-SENTENCE PUNCTUATION  # ETHIOPIC PREFACE COLON  ፦
U+1367  SENTENCE END PUNCTUATION  # ETHIOPIC QUESTION MARK  ፧
U+1368  SENTENCE END PUNCTUATION  # ETHIOPIC PARAGRAPH SEPARATOR    ፨
U+1400  HYPHEN  # CANADIAN SYLLABICS HYPHEN       ᐀
U+166D  IN-SENTENCE PUNCTUATION  # CANADIAN SYLLABICS CHI SIGN     ᙭
U+166E  IN-SENTENCE PUNCTUATION  # CANADIAN SYLLABICS FULL STOP    ᙮
U+1680  WHITESPACE  # OGHAM SPACE MARK         
U+169B  IN-SENTENCE PUNCTUATION  # OGHAM FEATHER MARK      ᚛
U+169C  IN-SENTENCE PUNCTUATION  # OGHAM REVERSED FEATHER MARK     ᚜
U+16EB  IN-SENTENCE PUNCTUATION  # RUNIC SINGLE PUNCTUATION        ᛫
U+16EC  IN-SENTENCE PUNCTUATION  # RUNIC MULTIPLE PUNCTUATION      ᛬
U+16ED  IN-SENTENCE PUNCTUATION  # RUNIC CROSS PUNCTUATION         ᛭
U+1735  IN-SENTENCE PUNCTUATION  # PHILIPPINE SINGLE PUNCTUATION   ᜵
U+1736  IN-SENTENCE PUNCTUATION  # PHILIPPINE DOUBLE PUNCTUATION   ᜶
U+17D4  IN-SENTENCE PUNCTUATION  # KHMER SIGN KHAN         ។
U+17D5  IN-SENTENCE PUNCTUATION  # KHMER SIGN BARIYOOSAN   ៕
U+17D6  IN-SENTENCE PUNCTUATION  # KHMER SIGN CAMNUC PII KUUH      ៖
U+17D8  IN-SENTENCE PUNCTUATION  # KHMER SIGN BEYYAL       ៘
U+17D9  IN-SENTENCE PUNCTUATION  # KHMER SIGN PHNAEK MUAN  ៙
U+17DA  IN-SENTENCE PUNCTUATION  # KHMER SIGN KOOMUUT      ៚
U+1800  IN-SENTENCE PUNCTUATION  # MONGOLIAN BIRGA         ᠀
U+1801  IN-SENTENCE PUNCTUATION  # MONGOLIAN ELLIPSIS      ᠁
U+1802  IN-SENTENCE PUNCTUATION  # MONGOLIAN COMMA         ᠂
U+1803  SENTENCE END PUNCTUATION  # MONGOLIAN FULL STOP     ᠃
U+1804  IN-SENTENCE PUNCTUATION  # MONGOLIAN COLON         ᠄
U+1805  IN-SENTENCE PUNCTUATION  # MONGOLIAN FOUR DOTS     ᠅
U+1806  HYPHEN  # MONGOLIAN TODO SOFT HYPHEN      ᠆
U+1807  IN-SENTENCE PUNCTUATION  # MONGOLIAN SIBE SYLLABLE BOUNDARY MARKER         ᠇
U+1808  IN-SENTENCE PUNCTUATION  # MONGOLIAN MANCHU COMMA  ᠈
U+1809  IN-SENTENCE PUNCTUATION  # MONGOLIAN MANCHU FULL STOP      ᠉
U+180A  IN-SENTENCE PUNCTUATION  # MONGOLIAN NIRUGU        ᠊
U+180E  WHITESPACE  # MONGOLIAN VOWEL SEPARATOR    ᠎
U+1944  SENTENCE END PUNCTUATION  # LIMBU EXCLAMATION MARK  ᥄
U+1945  SENTENCE END PUNCTUATION  # LIMBU QUESTION MARK     ᥅
U+1A1E  IN-SENTENCE PUNCTUATION  # BUGINESE PALLAWA        ᨞
U+1A1F  IN-SENTENCE PUNCTUATION  # BUGINESE END OF SECTION         ᨟
U+1AA0  IN-SENTENCE PUNCTUATION  # TAI THAM SIGN WIANG     ᪠
U+1AA1  IN-SENTENCE PUNCTUATION  # TAI THAM SIGN WIANGWAAK         ᪡
U+1AA2  IN-SENTENCE PUNCTUATION  # TAI THAM SIGN SAWAN     ᪢
U+1AA3  IN-SENTENCE PUNCTUATION  # TAI THAM SIGN KEOW      ᪣
U+1AA4  IN-SENTENCE PUNCTUATION  # TAI THAM SIGN HOY       ᪤
U+1AA5  IN-SENTENCE PUNCTUATION  # TAI THAM SIGN DOKMAI    ᪥
U+1AA6  IN-SENTENCE PUNCTUATION  # TAI THAM SIGN REVERSED ROTATED RANA     ᪦
U+1AA8  IN-SENTENCE PUNCTUATION  # TAI THAM SIGN KAAN      ᪨
U+1AA9  IN-SENTENCE PUNCTUATION  # TAI THAM SIGN KAANKUU   ᪩
U+1AAA  IN-SENTENCE PUNCTUATION  # TAI THAM SIGN SATKAAN   ᪪
U+1AAB  IN-SENTENCE PUNCTUATION  # TAI THAM SIGN SATKAANKUU        ᪫
U+1AAC  IN-SENTENCE PUNCTUATION  # TAI THAM SIGN HANG      ᪬
U+1AAD  IN-SENTENCE PUNCTUATION  # TAI THAM SIGN CAANG     ᪭
U+1B5A  IN-SENTENCE PUNCTUATION  # BALINESE PANTI  ᭚
U+1B5B  IN-SENTENCE PUNCTUATION  # BALINESE PAMADA         ᭛
U+1B5C  IN-SENTENCE PUNCTUATION  # BALINESE WINDU  ᭜
U+1B5D  IN-SENTENCE PUNCTUATION  # BALINESE CARIK PAMUNGKAH        ᭝
U+1B5E  IN-SENTENCE PUNCTUATION  # BALINESE CARIK SIKI     ᭞
U+1B5F  IN-SENTENCE PUNCTUATION  # BALINESE CARIK PAREREN  ᭟
U+1B60  IN-SENTENCE PUNCTUATION  # BALINESE PAMENENG       ᭠
U+1BFC  IN-SENTENCE PUNCTUATION  # BATAK SYMBOL BINDU NA METEK     ᯼
U+1BFD  IN-SENTENCE PUNCTUATION  # BATAK SYMBOL BINDU PINARBORAS   ᯽
U+1BFE  IN-SENTENCE PUNCTUATION  # BATAK SYMBOL BINDU JUDUL        ᯾
U+1BFF  IN-SENTENCE PUNCTUATION  # BATAK SYMBOL BINDU PANGOLAT     ᯿
U+1C3B  IN-SENTENCE PUNCTUATION  # LEPCHA PUNCTUATION TA-ROL       ᰻
U+1C3C  IN-SENTENCE PUNCTUATION  # LEPCHA PUNCTUATION NYET THYOOM TA-ROL   ᰼
U+1C3D  IN-SENTENCE PUNCTUATION  # LEPCHA PUNCTUATION CER-WA       ᰽
U+1C3E  IN-SENTENCE PUNCTUATION  # LEPCHA PUNCTUATION TSHOOK CER-WA        ᰾
U+1C3F  IN-SENTENCE PUNCTUATION  # LEPCHA PUNCTUATION TSHOOK       ᰿
U+1C7E  IN-SENTENCE PUNCTUATION  # OL CHIKI PUNCTUATION MUCAAD     ᱾
U+1C7F  IN-SENTENCE PUNCTUATION  # OL CHIKI PUNCTUATION DOUBLE MUCAAD      ᱿
U+1CC0  IN-SENTENCE PUNCTUATION  # SUNDANESE PUNCTUATION BINDU SURYA       ᳀
U+1CC1  IN-SENTENCE PUNCTUATION  # SUNDANESE PUNCTUATION BINDU PANGLONG    ᳁
U+1CC2  IN-SENTENCE PUNCTUATION  # SUNDANESE PUNCTUATION BINDU PURNAMA     ᳂
U+1CC3  IN-SENTENCE PUNCTUATION  # SUNDANESE PUNCTUATION BINDU CAKRA       ᳃
U+1CC4  IN-SENTENCE PUNCTUATION  # SUNDANESE PUNCTUATION BINDU LEU SATANGA         ᳄
U+1CC5  IN-SENTENCE PUNCTUATION  # SUNDANESE PUNCTUATION BINDU KA SATANGA  ᳅
U+1CC6  IN-SENTENCE PUNCTUATION  # SUNDANESE PUNCTUATION BINDU DA SATANGA  ᳆
U+1CC7  IN-SENTENCE PUNCTUATION  # SUNDANESE PUNCTUATION BINDU BA SATANGA  ᳇
U+1CD3  IN-SENTENCE PUNCTUATION  # VEDIC SIGN NIHSHVASA    ᳓
U+2000  WHITESPACE  # EN QUAD          
U+2001  WHITESPACE  # EM QUAD          
U+2002  WHITESPACE  # EN SPACE         
U+2003  WHITESPACE  # EM SPACE         
U+2004  WHITESPACE  # THREE-PER-EM SPACE       
U+2005  WHITESPACE  # FOUR-PER-EM SPACE        
U+2006  WHITESPACE  # SIX-PER-EM SPACE         
U+2007  WHITESPACE  # FIGURE SPACE     
U+2008  WHITESPACE  # PUNCTUATION SPACE        
U+2009  WHITESPACE  # THIN SPACE       
U+200A  WHITESPACE  # HAIR SPACE       
U+2010  HYPHEN  # HYPHEN  ‐
U+2011  HYPHEN  # NON-BREAKING HYPHEN     ‑
U+2012  IN-SENTENCE PUNCTUATION  # FIGURE DASH     ‒
U+2013  IN-SENTENCE PUNCTUATION  # EN DASH         –
U+2014  IN-SENTENCE PUNCTUATION  # EM DASH         —
U+2015  IN-SENTENCE PUNCTUATION  # HORIZONTAL BAR  ―
U+2016  IN-SENTENCE PUNCTUATION  # DOUBLE VERTICAL LINE    ‖
U+2017  IN-SENTENCE PUNCTUATION  # DOUBLE LOW LINE         ‗
U+2018  IN-SENTENCE PUNCTUATION  # LEFT SINGLE QUOTATION MARK      ‘
U+2019  IN-SENTENCE PUNCTUATION  # RIGHT SINGLE QUOTATION MARK     ’
U+201A  IN-SENTENCE PUNCTUATION  # SINGLE LOW-9 QUOTATION MARK     ‚
U+201B  IN-SENTENCE PUNCTUATION  # SINGLE HIGH-REVERSED-9 QUOTATION MARK   ‛
U+201C  IN-SENTENCE PUNCTUATION  # LEFT DOUBLE QUOTATION MARK      “
U+201D  IN-SENTENCE PUNCTUATION  # RIGHT DOUBLE QUOTATION MARK     ”
U+201E  IN-SENTENCE PUNCTUATION  # DOUBLE LOW-9 QUOTATION MARK     „
U+201F  IN-SENTENCE PUNCTUATION  # DOUBLE HIGH-REVERSED-9 QUOTATION MARK   ‟
U+2020  IN-SENTENCE PUNCTUATION  # DAGGER  †
U+2021  IN-SENTENCE PUNCTUATION  # DOUBLE DAGGER   ‡
U+2022  IN-SENTENCE PUNCTUATION  # BULLET  •
U+2023  IN-SENTENCE PUNCTUATION  # TRIANGULAR BULLET       ‣
U+2024  IN-SENTENCE PUNCTUATION  # ONE DOT LEADER  ․
U+2025  IN-SENTENCE PUNCTUATION  # TWO DOT LEADER  ‥
U+2026  SENTENCE END PUNCTUATION  # HORIZONTAL ELLIPSIS     …
U+2027  IN-SENTENCE PUNCTUATION  # HYPHENATION POINT       ‧
U+2028  WHITESPACE  # LINE SEPARATOR
U+2029  WHITESPACE  # PARAGRAPH SEPARATOR      
U+202F  WHITESPACE  # NARROW NO-BREAK SPACE    
U+2030  IN-SENTENCE PUNCTUATION  # PER MILLE SIGN  ‰
U+2031  IN-SENTENCE PUNCTUATION  # PER TEN THOUSAND SIGN   ‱
U+2032  IN-SENTENCE PUNCTUATION  # PRIME   ′
U+2033  IN-SENTENCE PUNCTUATION  # DOUBLE PRIME    ″
U+2034  IN-SENTENCE PUNCTUATION  # TRIPLE PRIME    ‴
U+2035  IN-SENTENCE PUNCTUATION  # REVERSED PRIME  ‵
U+2036  IN-SENTENCE PUNCTUATION  # REVERSED DOUBLE PRIME   ‶
U+2037  IN-SENTENCE PUNCTUATION  # REVERSED TRIPLE PRIME   ‷
U+2038  IN-SENTENCE PUNCTUATION  # CARET   ‸
U+2039  IN-SENTENCE PUNCTUATION  # SINGLE LEFT-POINTING ANGLE QUOTATION MARK       ‹
U+203A  IN-SENTENCE PUNCTUATION  # SINGLE RIGHT-POINTING ANGLE QUOTATION MARK      ›
U+203B  IN-SENTENCE PUNCTUATION  # REFERENCE MARK  ※
U+203C  SENTENCE END PUNCTUATION  # DOUBLE EXCLAMATION MARK         ‼
U+203D  SENTENCE END PUNCTUATION  # INTERROBANG     ‽
U+203E  IN-SENTENCE PUNCTUATION  # OVERLINE        ‾
U+203F  IN-SENTENCE PUNCTUATION  # UNDERTIE        ‿
U+2040  IN-SENTENCE PUNCTUATION  # CHARACTER TIE   ⁀
U+2041  IN-SENTENCE PUNCTUATION  # CARET INSERTION POINT   ⁁
U+2042  IN-SENTENCE PUNCTUATION  # ASTERISM        ⁂
U+2043  IN-SENTENCE PUNCTUATION  # HYPHEN BULLET   ⁃
U+2045  IN-SENTENCE PUNCTUATION  # LEFT SQUARE BRACKET WITH QUILL  ⁅
U+2046  IN-SENTENCE PUNCTUATION  # RIGHT SQUARE BRACKET WITH QUILL         ⁆
U+2047  SENTENCE END PUNCTUATION  # DOUBLE QUESTION MARK    ⁇
U+2048  SENTENCE END PUNCTUATION  # QUESTION EXCLAMATION MARK       ⁈
U+2049  SENTENCE END PUNCTUATION  # EXCLAMATION QUESTION MARK       ⁉
U+204A  IN-SENTENCE PUNCTUATION  # TIRONIAN SIGN ET        ⁊
U+204B  IN-SENTENCE PUNCTUATION  # REVERSED PILCROW SIGN   ⁋
U+204C  IN-SENTENCE PUNCTUATION  # BLACK LEFTWARDS BULLET  ⁌
U+204D  IN-SENTENCE PUNCTUATION  # BLACK RIGHTWARDS BULLET         ⁍
U+204E  IN-SENTENCE PUNCTUATION  # LOW ASTERISK    ⁎
U+204F  IN-SENTENCE PUNCTUATION  # REVERSED SEMICOLON      ⁏
U+2050  IN-SENTENCE PUNCTUATION  # CLOSE UP        ⁐
U+2051  IN-SENTENCE PUNCTUATION  # TWO ASTERISKS ALIGNED VERTICALLY        ⁑
U+2053  IN-SENTENCE PUNCTUATION  # SWUNG DASH      ⁓
U+2054  IN-SENTENCE PUNCTUATION  # INVERTED UNDERTIE       ⁔
U+2055  IN-SENTENCE PUNCTUATION  # FLOWER PUNCTUATION MARK         ⁕
U+2056  IN-SENTENCE PUNCTUATION  # THREE DOT PUNCTUATION   ⁖
U+2057  IN-SENTENCE PUNCTUATION  # QUADRUPLE PRIME         ⁗
U+2058  IN-SENTENCE PUNCTUATION  # FOUR DOT PUNCTUATION    ⁘
U+2059  IN-SENTENCE PUNCTUATION  # FIVE DOT PUNCTUATION    ⁙
U+205A  IN-SENTENCE PUNCTUATION  # TWO DOT PUNCTUATION     ⁚
U+205B  IN-SENTENCE PUNCTUATION  # FOUR DOT MARK   ⁛
U+205C  IN-SENTENCE PUNCTUATION  # DOTTED CROSS    ⁜
U+205D  IN-SENTENCE PUNCTUATION  # TRICOLON        ⁝
U+205E  IN-SENTENCE PUNCTUATION  # VERTICAL FOUR DOTS      ⁞
U+205F  WHITESPACE  # MEDIUM MATHEMATICAL SPACE        
U+207D  IN-SENTENCE PUNCTUATION  # SUPERSCRIPT LEFT PARENTHESIS    ⁽
U+207E  IN-SENTENCE PUNCTUATION  # SUPERSCRIPT RIGHT PARENTHESIS   ⁾
U+208D  IN-SENTENCE PUNCTUATION  # SUBSCRIPT LEFT PARENTHESIS      ₍
U+208E  IN-SENTENCE PUNCTUATION  # SUBSCRIPT RIGHT PARENTHESIS     ₎
U+2308  IN-SENTENCE PUNCTUATION  # LEFT CEILING    ⌈
U+2309  IN-SENTENCE PUNCTUATION  # RIGHT CEILING   ⌉
U+230A  IN-SENTENCE PUNCTUATION  # LEFT FLOOR      ⌊
U+230B  IN-SENTENCE PUNCTUATION  # RIGHT FLOOR     ⌋
U+2329  IN-SENTENCE PUNCTUATION  # LEFT-POINTING ANGLE BRACKET     〈
U+232A  IN-SENTENCE PUNCTUATION  # RIGHT-POINTING ANGLE BRACKET    〉
U+2768  IN-SENTENCE PUNCTUATION  # MEDIUM LEFT PARENTHESIS ORNAMENT        ❨
U+2769  IN-SENTENCE PUNCTUATION  # MEDIUM RIGHT PARENTHESIS ORNAMENT       ❩
U+276A  IN-SENTENCE PUNCTUATION  # MEDIUM FLATTENED LEFT PARENTHESIS ORNAMENT      ❪
U+276B  IN-SENTENCE PUNCTUATION  # MEDIUM FLATTENED RIGHT PARENTHESIS ORNAMENT     ❫
U+276C  IN-SENTENCE PUNCTUATION  # MEDIUM LEFT-POINTING ANGLE BRACKET ORNAMENT     ❬
U+276D  IN-SENTENCE PUNCTUATION  # MEDIUM RIGHT-POINTING ANGLE BRACKET ORNAMENT    ❭
U+276E  IN-SENTENCE PUNCTUATION  # HEAVY LEFT-POINTING ANGLE QUOTATION MARK ORNAMENT       ❮
U+276F  IN-SENTENCE PUNCTUATION  # HEAVY RIGHT-POINTING ANGLE QUOTATION MARK ORNAMENT      ❯
U+2770  IN-SENTENCE PUNCTUATION  # HEAVY LEFT-POINTING ANGLE BRACKET ORNAMENT      ❰
U+2771  IN-SENTENCE PUNCTUATION  # HEAVY RIGHT-POINTING ANGLE BRACKET ORNAMENT     ❱
U+2772  IN-SENTENCE PUNCTUATION  # LIGHT LEFT TORTOISE SHELL BRACKET ORNAMENT      ❲
U+2773  IN-SENTENCE PUNCTUATION  # LIGHT RIGHT TORTOISE SHELL BRACKET ORNAMENT     ❳
U+2774  IN-SENTENCE PUNCTUATION  # MEDIUM LEFT CURLY BRACKET ORNAMENT      ❴
U+2775  IN-SENTENCE PUNCTUATION  # MEDIUM RIGHT CURLY BRACKET ORNAMENT     ❵
U+27C5  IN-SENTENCE PUNCTUATION  # LEFT S-SHAPED BAG DELIMITER     ⟅
U+27C6  IN-SENTENCE PUNCTUATION  # RIGHT S-SHAPED BAG DELIMITER    ⟆
U+27E6  IN-SENTENCE PUNCTUATION  # MATHEMATICAL LEFT WHITE SQUARE BRACKET  ⟦
U+27E7  IN-SENTENCE PUNCTUATION  # MATHEMATICAL RIGHT WHITE SQUARE BRACKET         ⟧
U+27E8  IN-SENTENCE PUNCTUATION  # MATHEMATICAL LEFT ANGLE BRACKET         ⟨
U+27E9  IN-SENTENCE PUNCTUATION  # MATHEMATICAL RIGHT ANGLE BRACKET        ⟩
U+27EA  IN-SENTENCE PUNCTUATION  # MATHEMATICAL LEFT DOUBLE ANGLE BRACKET  ⟪
U+27EB  IN-SENTENCE PUNCTUATION  # MATHEMATICAL RIGHT DOUBLE ANGLE BRACKET         ⟫
U+27EC  IN-SENTENCE PUNCTUATION  # MATHEMATICAL LEFT WHITE TORTOISE SHELL BRACKET  ⟬
U+27ED  IN-SENTENCE PUNCTUATION  # MATHEMATICAL RIGHT WHITE TORTOISE SHELL BRACKET         ⟭
U+27EE  IN-SENTENCE PUNCTUATION  # MATHEMATICAL LEFT FLATTENED PARENTHESIS         ⟮
U+27EF  IN-SENTENCE PUNCTUATION  # MATHEMATICAL RIGHT FLATTENED PARENTHESIS        ⟯
U+2983  IN-SENTENCE PUNCTUATION  # LEFT WHITE CURLY BRACKET        ⦃
U+2984  IN-SENTENCE PUNCTUATION  # RIGHT WHITE CURLY BRACKET       ⦄
U+2985  IN-SENTENCE PUNCTUATION  # LEFT WHITE PARENTHESIS  ⦅
U+2986  IN-SENTENCE PUNCTUATION  # RIGHT WHITE PARENTHESIS         ⦆
U+2987  IN-SENTENCE PUNCTUATION  # Z NOTATION LEFT IMAGE BRACKET   ⦇
U+2988  IN-SENTENCE PUNCTUATION  # Z NOTATION RIGHT IMAGE BRACKET  ⦈
U+2989  IN-SENTENCE PUNCTUATION  # Z NOTATION LEFT BINDING BRACKET         ⦉
U+298A  IN-SENTENCE PUNCTUATION  # Z NOTATION RIGHT BINDING BRACKET        ⦊
U+298B  IN-SENTENCE PUNCTUATION  # LEFT SQUARE BRACKET WITH UNDERBAR       ⦋
U+298C  IN-SENTENCE PUNCTUATION  # RIGHT SQUARE BRACKET WITH UNDERBAR      ⦌
U+298D  IN-SENTENCE PUNCTUATION  # LEFT SQUARE BRACKET WITH TICK IN TOP CORNER     ⦍
U+298E  IN-SENTENCE PUNCTUATION  # RIGHT SQUARE BRACKET WITH TICK IN BOTTOM CORNER         ⦎
U+298F  IN-SENTENCE PUNCTUATION  # LEFT SQUARE BRACKET WITH TICK IN BOTTOM CORNER  ⦏
U+2990  IN-SENTENCE PUNCTUATION  # RIGHT SQUARE BRACKET WITH TICK IN TOP CORNER    ⦐
U+2991  IN-SENTENCE PUNCTUATION  # LEFT ANGLE BRACKET WITH DOT     ⦑
U+2992  IN-SENTENCE PUNCTUATION  # RIGHT ANGLE BRACKET WITH DOT    ⦒
U+2993  IN-SENTENCE PUNCTUATION  # LEFT ARC LESS-THAN BRACKET      ⦓
U+2994  IN-SENTENCE PUNCTUATION  # RIGHT ARC GREATER-THAN BRACKET  ⦔
U+2995  IN-SENTENCE PUNCTUATION  # DOUBLE LEFT ARC GREATER-THAN BRACKET    ⦕
U+2996  IN-SENTENCE PUNCTUATION  # DOUBLE RIGHT ARC LESS-THAN BRACKET      ⦖
U+2997  IN-SENTENCE PUNCTUATION  # LEFT BLACK TORTOISE SHELL BRACKET       ⦗
U+2998  IN-SENTENCE PUNCTUATION  # RIGHT BLACK TORTOISE SHELL BRACKET      ⦘
U+29D8  IN-SENTENCE PUNCTUATION  # LEFT WIGGLY FENCE       ⧘
U+29D9  IN-SENTENCE PUNCTUATION  # RIGHT WIGGLY FENCE      ⧙
U+29DA  IN-SENTENCE PUNCTUATION  # LEFT DOUBLE WIGGLY FENCE        ⧚
U+29DB  IN-SENTENCE PUNCTUATION  # RIGHT DOUBLE WIGGLY FENCE       ⧛
U+29FC  IN-SENTENCE PUNCTUATION  # LEFT-POINTING CURVED ANGLE BRACKET      ⧼
U+29FD  IN-SENTENCE PUNCTUATION  # RIGHT-POINTING CURVED ANGLE BRACKET     ⧽
U+2CF9  SENTENCE END PUNCTUATION  # COPTIC OLD NUBIAN FULL STOP     ⳹
U+2CFA  SENTENCE END PUNCTUATION  # COPTIC OLD NUBIAN DIRECT QUESTION MARK  ⳺
U+2CFB  SENTENCE END PUNCTUATION  # COPTIC OLD NUBIAN INDIRECT QUESTION MARK        ⳻
U+2CFC  SENTENCE END PUNCTUATION  # COPTIC OLD NUBIAN VERSE DIVIDER         ⳼
U+2CFE  SENTENCE END PUNCTUATION  # COPTIC FULL STOP        ⳾
U+2CFF  IN-SENTENCE PUNCTUATION  # COPTIC MORPHOLOGICAL DIVIDER    ⳿
U+2D70  IN-SENTENCE PUNCTUATION  # TIFINAGH SEPARATOR MARK         ⵰
U+2E00  IN-SENTENCE PUNCTUATION  # RIGHT ANGLE SUBSTITUTION MARKER         ⸀
U+2E01  IN-SENTENCE PUNCTUATION  # RIGHT ANGLE DOTTED SUBSTITUTION MARKER  ⸁
U+2E02  IN-SENTENCE PUNCTUATION  # LEFT SUBSTITUTION BRACKET       ⸂
U+2E03  IN-SENTENCE PUNCTUATION  # RIGHT SUBSTITUTION BRACKET      ⸃
U+2E04  IN-SENTENCE PUNCTUATION  # LEFT DOTTED SUBSTITUTION BRACKET        ⸄
U+2E05  IN-SENTENCE PUNCTUATION  # RIGHT DOTTED SUBSTITUTION BRACKET       ⸅
U+2E06  IN-SENTENCE PUNCTUATION  # RAISED INTERPOLATION MARKER     ⸆
U+2E07  IN-SENTENCE PUNCTUATION  # RAISED DOTTED INTERPOLATION MARKER      ⸇
U+2E08  IN-SENTENCE PUNCTUATION  # DOTTED TRANSPOSITION MARKER     ⸈
U+2E09  IN-SENTENCE PUNCTUATION  # LEFT TRANSPOSITION BRACKET      ⸉
U+2E0A  IN-SENTENCE PUNCTUATION  # RIGHT TRANSPOSITION BRACKET     ⸊
U+2E0B  IN-SENTENCE PUNCTUATION  # RAISED SQUARE   ⸋
U+2E0C  IN-SENTENCE PUNCTUATION  # LEFT RAISED OMISSION BRACKET    ⸌
U+2E0D  IN-SENTENCE PUNCTUATION  # RIGHT RAISED OMISSION BRACKET   ⸍
U+2E0E  IN-SENTENCE PUNCTUATION  # EDITORIAL CORONIS       ⸎
U+2E0F  IN-SENTENCE PUNCTUATION  # PARAGRAPHOS     ⸏
U+2E10  IN-SENTENCE PUNCTUATION  # FORKED PARAGRAPHOS      ⸐
U+2E11  IN-SENTENCE PUNCTUATION  # REVERSED FORKED PARAGRAPHOS     ⸑
U+2E12  IN-SENTENCE PUNCTUATION  # HYPODIASTOLE    ⸒
U+2E13  IN-SENTENCE PUNCTUATION  # DOTTED OBELOS   ⸓
U+2E14  IN-SENTENCE PUNCTUATION  # DOWNWARDS ANCORA        ⸔
U+2E15  IN-SENTENCE PUNCTUATION  # UPWARDS ANCORA  ⸕
U+2E16  IN-SENTENCE PUNCTUATION  # DOTTED RIGHT-POINTING ANGLE     ⸖
U+2E17  IN-SENTENCE PUNCTUATION  # DOUBLE OBLIQUE HYPHEN   ⸗
U+2E18  IN-SENTENCE PUNCTUATION  # INVERTED INTERROBANG    ⸘
U+2E19  IN-SENTENCE PUNCTUATION  # PALM BRANCH     ⸙
U+2E1A  HYPHEN  # HYPHEN WITH DIAERESIS   ⸚
U+2E1B  IN-SENTENCE PUNCTUATION  # TILDE WITH RING ABOVE   ⸛
U+2E1C  IN-SENTENCE PUNCTUATION  # LEFT LOW PARAPHRASE BRACKET     ⸜
U+2E1D  IN-SENTENCE PUNCTUATION  # RIGHT LOW PARAPHRASE BRACKET    ⸝
U+2E1E  IN-SENTENCE PUNCTUATION  # TILDE WITH DOT ABOVE    ⸞
U+2E1F  IN-SENTENCE PUNCTUATION  # TILDE WITH DOT BELOW    ⸟
U+2E20  IN-SENTENCE PUNCTUATION  # LEFT VERTICAL BAR WITH QUILL    ⸠
U+2E21  IN-SENTENCE PUNCTUATION  # RIGHT VERTICAL BAR WITH QUILL   ⸡
U+2E22  IN-SENTENCE PUNCTUATION  # TOP LEFT HALF BRACKET   ⸢
U+2E23  IN-SENTENCE PUNCTUATION  # TOP RIGHT HALF BRACKET  ⸣
U+2E24  IN-SENTENCE PUNCTUATION  # BOTTOM LEFT HALF BRACKET        ⸤
U+2E25  IN-SENTENCE PUNCTUATION  # BOTTOM RIGHT HALF BRACKET       ⸥
U+2E26  IN-SENTENCE PUNCTUATION  # LEFT SIDEWAYS U BRACKET         ⸦
U+2E27  IN-SENTENCE PUNCTUATION  # RIGHT SIDEWAYS U BRACKET        ⸧
U+2E28  IN-SENTENCE PUNCTUATION  # LEFT DOUBLE PARENTHESIS         ⸨
U+2E29  IN-SENTENCE PUNCTUATION  # RIGHT DOUBLE PARENTHESIS        ⸩
U+2E2A  IN-SENTENCE PUNCTUATION  # TWO DOTS OVER ONE DOT PUNCTUATION       ⸪
U+2E2B  IN-SENTENCE PUNCTUATION  # ONE DOT OVER TWO DOTS PUNCTUATION       ⸫
U+2E2C  IN-SENTENCE PUNCTUATION  # SQUARED FOUR DOT PUNCTUATION    ⸬
U+2E2D  IN-SENTENCE PUNCTUATION  # FIVE DOT MARK   ⸭
U+2E2E  IN-SENTENCE PUNCTUATION  # REVERSED QUESTION MARK  ⸮
U+2E30  IN-SENTENCE PUNCTUATION  # RING POINT      ⸰
U+2E31  IN-SENTENCE PUNCTUATION  # WORD SEPARATOR MIDDLE DOT       ⸱
U+2E32  IN-SENTENCE PUNCTUATION  # TURNED COMMA    ⸲
U+2E33  IN-SENTENCE PUNCTUATION  # RAISED DOT      ⸳
U+2E34  IN-SENTENCE PUNCTUATION  # RAISED COMMA    ⸴
U+2E35  IN-SENTENCE PUNCTUATION  # TURNED SEMICOLON        ⸵
U+2E36  IN-SENTENCE PUNCTUATION  # DAGGER WITH LEFT GUARD  ⸶
U+2E37  IN-SENTENCE PUNCTUATION  # DAGGER WITH RIGHT GUARD         ⸷
U+2E38  IN-SENTENCE PUNCTUATION  # TURNED DAGGER   ⸸
U+2E39  IN-SENTENCE PUNCTUATION  # TOP HALF SECTION SIGN   ⸹
U+2E3A  IN-SENTENCE PUNCTUATION  # TWO-EM DASH     ⸺
U+2E3B  IN-SENTENCE PUNCTUATION  # THREE-EM DASH   ⸻
U+2E3C  SENTENCE END PUNCTUATION  # STENOGRAPHIC FULL STOP  ⸼
U+2E3D  IN-SENTENCE PUNCTUATION  # VERTICAL SIX DOTS       ⸽
U+2E3E  IN-SENTENCE PUNCTUATION  # WIGGLY VERTICAL LINE    ⸾
U+2E3F  IN-SENTENCE PUNCTUATION  # CAPITULUM       ⸿
U+2E40  HYPHEN  # DOUBLE HYPHEN   ⹀
U+2E41  IN-SENTENCE PUNCTUATION  # REVERSED COMMA  ⹁
U+2E42  IN-SENTENCE PUNCTUATION  # DOUBLE LOW-REVERSED-9 QUOTATION MARK    ⹂
U+3000  WHITESPACE  # IDEOGRAPHIC SPACE       　
U+3001  IN-SENTENCE PUNCTUATION  # IDEOGRAPHIC COMMA       、
U+3002  SENTENCE END PUNCTUATION  # IDEOGRAPHIC FULL STOP   。
U+3003  IN-SENTENCE PUNCTUATION  # DITTO MARK      〃
U+3008  IN-SENTENCE PUNCTUATION  # LEFT ANGLE BRACKET      〈
U+3009  IN-SENTENCE PUNCTUATION  # RIGHT ANGLE BRACKET     〉
U+300A  IN-SENTENCE PUNCTUATION  # LEFT DOUBLE ANGLE BRACKET       《
U+300B  IN-SENTENCE PUNCTUATION  # RIGHT DOUBLE ANGLE BRACKET      》
U+300C  IN-SENTENCE PUNCTUATION  # LEFT CORNER BRACKET     「
U+300D  IN-SENTENCE PUNCTUATION  # RIGHT CORNER BRACKET    」
U+300E  IN-SENTENCE PUNCTUATION  # LEFT WHITE CORNER BRACKET       『
U+300F  IN-SENTENCE PUNCTUATION  # RIGHT WHITE CORNER BRACKET      』
U+3010  IN-SENTENCE PUNCTUATION  # LEFT BLACK LENTICULAR BRACKET   【
U+3011  IN-SENTENCE PUNCTUATION  # RIGHT BLACK LENTICULAR BRACKET  】
U+3014  IN-SENTENCE PUNCTUATION  # LEFT TORTOISE SHELL BRACKET     〔
U+3015  IN-SENTENCE PUNCTUATION  # RIGHT TORTOISE SHELL BRACKET    〕
U+3016  IN-SENTENCE PUNCTUATION  # LEFT WHITE LENTICULAR BRACKET   〖
U+3017  IN-SENTENCE PUNCTUATION  # RIGHT WHITE LENTICULAR BRACKET  〗
U+3018  IN-SENTENCE PUNCTUATION  # LEFT WHITE TORTOISE SHELL BRACKET       〘
U+3019  IN-SENTENCE PUNCTUATION  # RIGHT WHITE TORTOISE SHELL BRACKET      〙
U+301A  IN-SENTENCE PUNCTUATION  # LEFT WHITE SQUARE BRACKET       〚
U+301B  IN-SENTENCE PUNCTUATION  # RIGHT WHITE SQUARE BRACKET      〛
U+301C  IN-SENTENCE PUNCTUATION  # WAVE DASH       〜
U+301D  IN-SENTENCE PUNCTUATION  # REVERSED DOUBLE PRIME QUOTATION MARK    〝
U+301E  IN-SENTENCE PUNCTUATION  # DOUBLE PRIME QUOTATION MARK     〞
U+301F  IN-SENTENCE PUNCTUATION  # LOW DOUBLE PRIME QUOTATION MARK         〟
U+3030  IN-SENTENCE PUNCTUATION  # WAVY DASH       〰
U+303D  IN-SENTENCE PUNCTUATION  # PART ALTERNATION MARK   〽
U+30A0  HYPHEN  # KATAKANA-HIRAGANA DOUBLE HYPHEN         ゠
U+30FB  IN-SENTENCE PUNCTUATION  # KATAKANA MIDDLE DOT     ・
U+A4FE  IN-SENTENCE PUNCTUATION  # LISU PUNCTUATION COMMA  ꓾
U+A4FF  SENTENCE END PUNCTUATION  # LISU PUNCTUATION FULL STOP      ꓿
U+A60D  IN-SENTENCE PUNCTUATION  # VAI COMMA       ꘍
U+A60E  SENTENCE END PUNCTUATION  # VAI FULL STOP   ꘎
U+A60F  SENTENCE END PUNCTUATION  # VAI QUESTION MARK       ꘏
U+A673  IN-SENTENCE PUNCTUATION  # SLAVONIC ASTERISK       ꙳
U+A67E  IN-SENTENCE PUNCTUATION  # CYRILLIC KAVYKA         ꙾
U+A6F2  IN-SENTENCE PUNCTUATION  # BAMUM NJAEMLI   ꛲
U+A6F3  SENTENCE END PUNCTUATION  # BAMUM FULL STOP         ꛳
U+A6F4  IN-SENTENCE PUNCTUATION  # BAMUM COLON     ꛴
U+A6F5  IN-SENTENCE PUNCTUATION  # BAMUM COMMA     ꛵
U+A6F6  IN-SENTENCE PUNCTUATION  # BAMUM SEMICOLON         ꛶
U+A6F7  SENTENCE END PUNCTUATION  # BAMUM QUESTION MARK     ꛷
U+A874  IN-SENTENCE PUNCTUATION  # PHAGS-PA SINGLE HEAD MARK       ꡴
U+A875  IN-SENTENCE PUNCTUATION  # PHAGS-PA DOUBLE HEAD MARK       ꡵
U+A876  IN-SENTENCE PUNCTUATION  # PHAGS-PA MARK SHAD      ꡶
U+A877  IN-SENTENCE PUNCTUATION  # PHAGS-PA MARK DOUBLE SHAD       ꡷
U+A8CE  IN-SENTENCE PUNCTUATION  # SAURASHTRA DANDA        ꣎
U+A8CF  IN-SENTENCE PUNCTUATION  # SAURASHTRA DOUBLE DANDA         ꣏
U+A8F8  IN-SENTENCE PUNCTUATION  # DEVANAGARI SIGN PUSHPIKA        ꣸
U+A8F9  IN-SENTENCE PUNCTUATION  # DEVANAGARI GAP FILLER   ꣹
U+A8FA  IN-SENTENCE PUNCTUATION  # DEVANAGARI CARET        ꣺
U+A8FC  IN-SENTENCE PUNCTUATION  # DEVANAGARI SIGN SIDDHAM         ꣼
U+A92E  IN-SENTENCE PUNCTUATION  # KAYAH LI SIGN CWI       ꤮
U+A92F  IN-SENTENCE PUNCTUATION  # KAYAH LI SIGN SHYA      ꤯
U+A95F  IN-SENTENCE PUNCTUATION  # REJANG SECTION MARK     ꥟
U+A9C1  IN-SENTENCE PUNCTUATION  # JAVANESE LEFT RERENGGAN         ꧁
U+A9C2  IN-SENTENCE PUNCTUATION  # JAVANESE RIGHT RERENGGAN        ꧂
U+A9C3  IN-SENTENCE PUNCTUATION  # JAVANESE PADA ANDAP     ꧃
U+A9C4  IN-SENTENCE PUNCTUATION  # JAVANESE PADA MADYA     ꧄
U+A9C5  IN-SENTENCE PUNCTUATION  # JAVANESE PADA LUHUR     ꧅
U+A9C6  IN-SENTENCE PUNCTUATION  # JAVANESE PADA WINDU     ꧆
U+A9C7  IN-SENTENCE PUNCTUATION  # JAVANESE PADA PANGKAT   ꧇
U+A9C8  IN-SENTENCE PUNCTUATION  # JAVANESE PADA LINGSA    ꧈
U+A9C9  IN-SENTENCE PUNCTUATION  # JAVANESE PADA LUNGSI    ꧉
U+A9CA  IN-SENTENCE PUNCTUATION  # JAVANESE PADA ADEG      ꧊
U+A9CB  IN-SENTENCE PUNCTUATION  # JAVANESE PADA ADEG ADEG         ꧋
U+A9CC  IN-SENTENCE PUNCTUATION  # JAVANESE PADA PISELEH   ꧌
U+A9CD  IN-SENTENCE PUNCTUATION  # JAVANESE TURNED PADA PISELEH    ꧍
U+A9DE  IN-SENTENCE PUNCTUATION  # JAVANESE PADA TIRTA TUMETES     ꧞
U+A9DF  IN-SENTENCE PUNCTUATION  # JAVANESE PADA ISEN-ISEN         ꧟
U+AA5C  IN-SENTENCE PUNCTUATION  # CHAM PUNCTUATION SPIRAL         ꩜
U+AA5D  IN-SENTENCE PUNCTUATION  # CHAM PUNCTUATION DANDA  ꩝
U+AA5E  IN-SENTENCE PUNCTUATION  # CHAM PUNCTUATION DOUBLE DANDA   ꩞
U+AA5F  IN-SENTENCE PUNCTUATION  # CHAM PUNCTUATION TRIPLE DANDA   ꩟
U+AADE  IN-SENTENCE PUNCTUATION  # TAI VIET SYMBOL HO HOI  ꫞
U+AADF  IN-SENTENCE PUNCTUATION  # TAI VIET SYMBOL KOI KOI         ꫟
U+AAF0  IN-SENTENCE PUNCTUATION  # MEETEI MAYEK CHEIKHAN   ꫰
U+AAF1  IN-SENTENCE PUNCTUATION  # MEETEI MAYEK AHANG KHUDAM       ꫱
U+ABEB  IN-SENTENCE PUNCTUATION  # MEETEI MAYEK CHEIKHEI   ꯫
U+FD3E  IN-SENTENCE PUNCTUATION  # ORNATE LEFT PARENTHESIS         ﴾
U+FD3F  IN-SENTENCE PUNCTUATION  # ORNATE RIGHT PARENTHESIS        ﴿
U+FE10  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL COMMA    ︐
U+FE11  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL IDEOGRAPHIC COMMA        ︑
U+FE12  SENTENCE END PUNCTUATION  # PRESENTATION FORM FOR VERTICAL IDEOGRAPHIC FULL STOP    ︒
U+FE13  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL COLON    ︓
U+FE14  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL SEMICOLON        ︔
U+FE15  SENTENCE END PUNCTUATION  # PRESENTATION FORM FOR VERTICAL EXCLAMATION MARK         ︕
U+FE16  SENTENCE END PUNCTUATION  # PRESENTATION FORM FOR VERTICAL QUESTION MARK    ︖
U+FE17  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL LEFT WHITE LENTICULAR BRACKET    ︗
U+FE18  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL RIGHT WHITE LENTICULAR BRAKCET   ︘
U+FE19  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL HORIZONTAL ELLIPSIS      ︙
U+FE30  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL TWO DOT LEADER   ︰
U+FE31  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL EM DASH  ︱
U+FE32  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL EN DASH  ︲
U+FE33  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL LOW LINE         ︳
U+FE34  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL WAVY LOW LINE    ︴
U+FE35  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL LEFT PARENTHESIS         ︵
U+FE36  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL RIGHT PARENTHESIS        ︶
U+FE37  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL LEFT CURLY BRACKET       ︷
U+FE38  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL RIGHT CURLY BRACKET      ︸
U+FE39  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL LEFT TORTOISE SHELL BRACKET      ︹
U+FE3A  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL RIGHT TORTOISE SHELL BRACKET     ︺
U+FE3B  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL LEFT BLACK LENTICULAR BRACKET    ︻
U+FE3C  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL RIGHT BLACK LENTICULAR BRACKET   ︼
U+FE3D  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL LEFT DOUBLE ANGLE BRACKET        ︽
U+FE3E  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL RIGHT DOUBLE ANGLE BRACKET       ︾
U+FE3F  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL LEFT ANGLE BRACKET       ︿
U+FE40  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL RIGHT ANGLE BRACKET      ﹀
U+FE41  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL LEFT CORNER BRACKET      ﹁
U+FE42  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL RIGHT CORNER BRACKET     ﹂
U+FE43  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL LEFT WHITE CORNER BRACKET        ﹃
U+FE44  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL RIGHT WHITE CORNER BRACKET       ﹄
U+FE45  IN-SENTENCE PUNCTUATION  # SESAME DOT      ﹅
U+FE46  IN-SENTENCE PUNCTUATION  # WHITE SESAME DOT        ﹆
U+FE47  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL LEFT SQUARE BRACKET      ﹇
U+FE48  IN-SENTENCE PUNCTUATION  # PRESENTATION FORM FOR VERTICAL RIGHT SQUARE BRACKET     ﹈
U+FE49  IN-SENTENCE PUNCTUATION  # DASHED OVERLINE         ﹉
U+FE4A  IN-SENTENCE PUNCTUATION  # CENTRELINE OVERLINE     ﹊
U+FE4B  IN-SENTENCE PUNCTUATION  # WAVY OVERLINE   ﹋
U+FE4C  IN-SENTENCE PUNCTUATION  # DOUBLE WAVY OVERLINE    ﹌
U+FE4D  IN-SENTENCE PUNCTUATION  # DASHED LOW LINE         ﹍
U+FE4E  IN-SENTENCE PUNCTUATION  # CENTRELINE LOW LINE     ﹎
U+FE4F  IN-SENTENCE PUNCTUATION  # WAVY LOW LINE   ﹏
U+FE50  IN-SENTENCE PUNCTUATION  # SMALL COMMA     ﹐
U+FE51  IN-SENTENCE PUNCTUATION  # SMALL IDEOGRAPHIC COMMA         ﹑
U+FE52  SENTENCE END PUNCTUATION  # SMALL FULL STOP         ﹒
U+FE54  IN-SENTENCE PUNCTUATION  # SMALL SEMICOLON         ﹔
U+FE55  IN-SENTENCE PUNCTUATION  # SMALL COLON     ﹕
U+FE56  SENTENCE END PUNCTUATION  # SMALL QUESTION MARK     ﹖
U+FE57  SENTENCE END PUNCTUATION  # SMALL EXCLAMATION MARK  ﹗
U+FE58  IN-SENTENCE PUNCTUATION  # SMALL EM DASH   ﹘
U+FE59  IN-SENTENCE PUNCTUATION  # SMALL LEFT PARENTHESIS  ﹙
U+FE5A  IN-SENTENCE PUNCTUATION  # SMALL RIGHT PARENTHESIS         ﹚
U+FE5B  IN-SENTENCE PUNCTUATION  # SMALL LEFT CURLY BRACKET        ﹛
U+FE5C  IN-SENTENCE PUNCTUATION  # SMALL RIGHT CURLY BRACKET       ﹜
U+FE5D  IN-SENTENCE PUNCTUATION  # SMALL LEFT TORTOISE SHELL BRACKET       ﹝
U+FE5E  IN-SENTENCE PUNCTUATION  # SMALL RIGHT TORTOISE SHELL BRACKET      ﹞
U+FE5F  IN-SENTENCE PUNCTUATION  # SMALL NUMBER SIGN       ﹟
U+FE60  IN-SENTENCE PUNCTUATION  # SMALL AMPERSAND         ﹠
U+FE61  IN-SENTENCE PUNCTUATION  # SMALL ASTERISK  ﹡
U+FE63  HYPHEN  # SMALL HYPHEN-MINUS      ﹣
U+FE68  IN-SENTENCE PUNCTUATION  # SMALL REVERSE SOLIDUS   ﹨
U+FE6A  IN-SENTENCE PUNCTUATION  # SMALL PERCENT SIGN      ﹪
U+FE6B  IN-SENTENCE PUNCTUATION  # SMALL COMMERCIAL AT     ﹫
U+FF01  SENTENCE END PUNCTUATION  # FULLWIDTH EXCLAMATION MARK      ！
U+FF02  IN-SENTENCE PUNCTUATION  # FULLWIDTH QUOTATION MARK        ＂
U+FF03  IN-SENTENCE PUNCTUATION  # FULLWIDTH NUMBER SIGN   ＃
U+FF05  IN-SENTENCE PUNCTUATION  # FULLWIDTH PERCENT SIGN  ％
U+FF06  IN-SENTENCE PUNCTUATION  # FULLWIDTH AMPERSAND     ＆
U+FF07  LETTER OR DIGIT  # FULLWIDTH APOSTROPHE    ＇     # In words like “let's“.
U+FF08  IN-SENTENCE PUNCTUATION  # FULLWIDTH LEFT PARENTHESIS      （
U+FF09  IN-SENTENCE PUNCTUATION  # FULLWIDTH RIGHT PARENTHESIS     ）
U+FF0A  IN-SENTENCE PUNCTUATION  # FULLWIDTH ASTERISK      ＊
U+FF0C  IN-SENTENCE PUNCTUATION  # FULLWIDTH COMMA         ，
U+FF0D  HYPHEN  # FULLWIDTH HYPHEN-MINUS  －
U+FF0E  SENTENCE END PUNCTUATION  # FULLWIDTH FULL STOP     ．
U+FF0F  IN-SENTENCE PUNCTUATION  # FULLWIDTH SOLIDUS       ／
U+FF1A  IN-SENTENCE PUNCTUATION  # FULLWIDTH COLON         ：
U+FF1B  IN-SENTENCE PUNCTUATION  # FULLWIDTH SEMICOLON     ；
U+FF1F  SENTENCE END PUNCTUATION  # FULLWIDTH QUESTION MARK         ？
U+FF20  IN-SENTENCE PUNCTUATION  # FULLWIDTH COMMERCIAL AT         ＠
U+FF3B  IN-SENTENCE PUNCTUATION  # FULLWIDTH LEFT SQUARE BRACKET   ［
U+FF3C  IN-SENTENCE PUNCTUATION  # FULLWIDTH REVERSE SOLIDUS       ＼
U+FF3D  IN-SENTENCE PUNCTUATION  # FULLWIDTH RIGHT SQUARE BRACKET  ］
U+FF3F  IN-SENTENCE PUNCTUATION  # FULLWIDTH LOW LINE      ＿
U+FF5B  IN-SENTENCE PUNCTUATION  # FULLWIDTH LEFT CURLY BRACKET    ｛
U+FF5D  IN-SENTENCE PUNCTUATION  # FULLWIDTH RIGHT CURLY BRACKET   ｝
U+FF5F  IN-SENTENCE PUNCTUATION  # FULLWIDTH LEFT WHITE PARENTHESIS        ｟
U+FF60  IN-SENTENCE PUNCTUATION  # FULLWIDTH RIGHT WHITE PARENTHESIS       ｠
U+FF61  SENTENCE END PUNCTUATION  # HALFWIDTH IDEOGRAPHIC FULL STOP         ｡
U+FF62  IN-SENTENCE PUNCTUATION  # HALFWIDTH LEFT CORNER BRACKET   ｢
U+FF63  IN-SENTENCE PUNCTUATION  # HALFWIDTH RIGHT CORNER BRACKET  ｣
U+FF64  IN-SENTENCE PUNCTUATION  # HALFWIDTH IDEOGRAPHIC COMMA     ､
U+FF65  IN-SENTENCE PUNCTUATION  # HALFWIDTH KATAKANA MIDDLE DOT   ･
U+10100  IN-SENTENCE PUNCTUATION  # AEGEAN WORD SEPARATOR LINE      𐄀
U+10101  IN-SENTENCE PUNCTUATION  # AEGEAN WORD SEPARATOR DOT       𐄁
U+10102  IN-SENTENCE PUNCTUATION  # AEGEAN CHECK MARK       𐄂
U+1039F  IN-SENTENCE PUNCTUATION  # UGARITIC WORD DIVIDER   𐎟
U+103D0  IN-SENTENCE PUNCTUATION  # OLD PERSIAN WORD DIVIDER        𐏐
U+1056F  IN-SENTENCE PUNCTUATION  # CAUCASIAN ALBANIAN CITATION MARK        𐕯
U+10857  IN-SENTENCE PUNCTUATION  # IMPERIAL ARAMAIC SECTION SIGN   𐡗
U+1091F  IN-SENTENCE PUNCTUATION  # PHOENICIAN WORD SEPARATOR       𐤟
U+1093F  IN-SENTENCE PUNCTUATION  # LYDIAN TRIANGULAR MARK  𐤿
U+10A50  IN-SENTENCE PUNCTUATION  # KHAROSHTHI PUNCTUATION DOT      𐩐
U+10A51  IN-SENTENCE PUNCTUATION  # KHAROSHTHI PUNCTUATION SMALL CIRCLE     𐩑
U+10A52  IN-SENTENCE PUNCTUATION  # KHAROSHTHI PUNCTUATION CIRCLE   𐩒
U+10A53  IN-SENTENCE PUNCTUATION  # KHAROSHTHI PUNCTUATION CRESCENT BAR     𐩓
U+10A54  IN-SENTENCE PUNCTUATION  # KHAROSHTHI PUNCTUATION MANGALAM         𐩔
U+10A55  IN-SENTENCE PUNCTUATION  # KHAROSHTHI PUNCTUATION LOTUS    𐩕
U+10A56  IN-SENTENCE PUNCTUATION  # KHAROSHTHI PUNCTUATION DANDA    𐩖
U+10A57  IN-SENTENCE PUNCTUATION  # KHAROSHTHI PUNCTUATION DOUBLE DANDA     𐩗
U+10A58  IN-SENTENCE PUNCTUATION  # KHAROSHTHI PUNCTUATION LINES    𐩘
U+10A7F  IN-SENTENCE PUNCTUATION  # OLD SOUTH ARABIAN NUMERIC INDICATOR     𐩿
U+10AF0  IN-SENTENCE PUNCTUATION  # MANICHAEAN PUNCTUATION STAR     𐫰
U+10AF1  IN-SENTENCE PUNCTUATION  # MANICHAEAN PUNCTUATION FLEURON  𐫱
U+10AF2  IN-SENTENCE PUNCTUATION  # MANICHAEAN PUNCTUATION DOUBLE DOT WITHIN DOT    𐫲
U+10AF3  IN-SENTENCE PUNCTUATION  # MANICHAEAN PUNCTUATION DOT WITHIN DOT   𐫳
U+10AF4  IN-SENTENCE PUNCTUATION  # MANICHAEAN PUNCTUATION DOT      𐫴
U+10AF5  IN-SENTENCE PUNCTUATION  # MANICHAEAN PUNCTUATION TWO DOTS         𐫵
U+10AF6  IN-SENTENCE PUNCTUATION  # MANICHAEAN PUNCTUATION LINE FILLER      𐫶
U+10B39  IN-SENTENCE PUNCTUATION  # AVESTAN ABBREVIATION MARK       𐬹
U+10B3A  IN-SENTENCE PUNCTUATION  # TINY TWO DOTS OVER ONE DOT PUNCTUATION  𐬺
U+10B3B  IN-SENTENCE PUNCTUATION  # SMALL TWO DOTS OVER ONE DOT PUNCTUATION         𐬻
U+10B3C  IN-SENTENCE PUNCTUATION  # LARGE TWO DOTS OVER ONE DOT PUNCTUATION         𐬼
U+10B3D  IN-SENTENCE PUNCTUATION  # LARGE ONE DOT OVER TWO DOTS PUNCTUATION         𐬽
U+10B3E  IN-SENTENCE PUNCTUATION  # LARGE TWO RINGS OVER ONE RING PUNCTUATION       𐬾
U+10B3F  IN-SENTENCE PUNCTUATION  # LARGE ONE RING OVER TWO RINGS PUNCTUATION       𐬿
U+10B99  IN-SENTENCE PUNCTUATION  # PSALTER PAHLAVI SECTION MARK    𐮙
U+10B9A  IN-SENTENCE PUNCTUATION  # PSALTER PAHLAVI TURNED SECTION MARK     𐮚
U+10B9B  IN-SENTENCE PUNCTUATION  # PSALTER PAHLAVI FOUR DOTS WITH CROSS    𐮛
U+10B9C  IN-SENTENCE PUNCTUATION  # PSALTER PAHLAVI FOUR DOTS WITH DOT      𐮜
U+11047  IN-SENTENCE PUNCTUATION  # BRAHMI DANDA    𑁇
U+11048  IN-SENTENCE PUNCTUATION  # BRAHMI DOUBLE DANDA     𑁈
U+11049  IN-SENTENCE PUNCTUATION  # BRAHMI PUNCTUATION DOT  𑁉
U+1104A  IN-SENTENCE PUNCTUATION  # BRAHMI PUNCTUATION DOUBLE DOT   𑁊
U+1104B  IN-SENTENCE PUNCTUATION  # BRAHMI PUNCTUATION LINE         𑁋
U+1104C  IN-SENTENCE PUNCTUATION  # BRAHMI PUNCTUATION CRESCENT BAR         𑁌
U+1104D  IN-SENTENCE PUNCTUATION  # BRAHMI PUNCTUATION LOTUS        𑁍
U+110BB  IN-SENTENCE PUNCTUATION  # KAITHI ABBREVIATION SIGN        𑂻
U+110BC  IN-SENTENCE PUNCTUATION  # KAITHI ENUMERATION SIGN         𑂼
U+110BE  IN-SENTENCE PUNCTUATION  # KAITHI SECTION MARK     𑂾
U+110BF  IN-SENTENCE PUNCTUATION  # KAITHI DOUBLE SECTION MARK      𑂿
U+110C0  IN-SENTENCE PUNCTUATION  # KAITHI DANDA    𑃀
U+110C1  IN-SENTENCE PUNCTUATION  # KAITHI DOUBLE DANDA     𑃁
U+11140  IN-SENTENCE PUNCTUATION  # CHAKMA SECTION MARK     𑅀
U+11141  IN-SENTENCE PUNCTUATION  # CHAKMA DANDA    𑅁
U+11142  IN-SENTENCE PUNCTUATION  # CHAKMA DOUBLE DANDA     𑅂
U+11143  IN-SENTENCE PUNCTUATION  # CHAKMA QUESTION MARK    𑅃
U+11174  IN-SENTENCE PUNCTUATION  # MAHAJANI ABBREVIATION SIGN      𑅴
U+11175  IN-SENTENCE PUNCTUATION  # MAHAJANI SECTION MARK   𑅵
U+111C5  IN-SENTENCE PUNCTUATION  # SHARADA DANDA   𑇅
U+111C6  IN-SENTENCE PUNCTUATION  # SHARADA DOUBLE DANDA    𑇆
U+111C7  IN-SENTENCE PUNCTUATION  # SHARADA ABBREVIATION SIGN       𑇇
U+111C8  IN-SENTENCE PUNCTUATION  # SHARADA SEPARATOR       𑇈
U+111C9  IN-SENTENCE PUNCTUATION  # SHARADA SANDHI MARK     𑇉
U+111CD  IN-SENTENCE PUNCTUATION  # SHARADA SUTRA MARK      𑇍
U+111DB  IN-SENTENCE PUNCTUATION  # SHARADA SIGN SIDDHAM    𑇛
U+111DD  IN-SENTENCE PUNCTUATION  # SHARADA CONTINUATION SIGN       𑇝
U+111DE  IN-SENTENCE PUNCTUATION  # SHARADA SECTION MARK-1  𑇞
U+111DF  IN-SENTENCE PUNCTUATION  # SHARADA SECTION MARK-2  𑇟
U+11238  IN-SENTENCE PUNCTUATION  # KHOJKI DANDA    𑈸
U+11239  IN-SENTENCE PUNCTUATION  # KHOJKI DOUBLE DANDA     𑈹
U+1123A  IN-SENTENCE PUNCTUATION  # KHOJKI WORD SEPARATOR   𑈺
U+1123B  IN-SENTENCE PUNCTUATION  # KHOJKI SECTION MARK     𑈻
U+1123C  IN-SENTENCE PUNCTUATION  # KHOJKI DOUBLE SECTION MARK      𑈼
U+1123D  IN-SENTENCE PUNCTUATION  # KHOJKI ABBREVIATION SIGN        𑈽
U+112A9  IN-SENTENCE PUNCTUATION  # MULTANI SECTION MARK    𑊩
U+114C6  IN-SENTENCE PUNCTUATION  # TIRHUTA ABBREVIATION SIGN       𑓆
U+115C1  IN-SENTENCE PUNCTUATION  # SIDDHAM SIGN SIDDHAM    𑗁
U+115C2  IN-SENTENCE PUNCTUATION  # SIDDHAM DANDA   𑗂
U+115C3  IN-SENTENCE PUNCTUATION  # SIDDHAM DOUBLE DANDA    𑗃
U+115C4  IN-SENTENCE PUNCTUATION  # SIDDHAM SEPARATOR DOT   𑗄
U+115C5  IN-SENTENCE PUNCTUATION  # SIDDHAM SEPARATOR BAR   𑗅
U+115C6  IN-SENTENCE PUNCTUATION  # SIDDHAM REPETITION MARK-1       𑗆
U+115C7  IN-SENTENCE PUNCTUATION  # SIDDHAM REPETITION MARK-2       𑗇
U+115C8  IN-SENTENCE PUNCTUATION  # SIDDHAM REPETITION MARK-3       𑗈
U+115C9  SENTENCE END PUNCTUATION  # SIDDHAM END OF TEXT MARK        𑗉
U+115CA  IN-SENTENCE PUNCTUATION  # SIDDHAM SECTION MARK WITH TRIDENT AND U-SHAPED ORNAMENTS        𑗊
U+115CB  IN-SENTENCE PUNCTUATION  # SIDDHAM SECTION MARK WITH TRIDENT AND DOTTED CRESCENTS  𑗋
U+115CC  IN-SENTENCE PUNCTUATION  # SIDDHAM SECTION MARK WITH RAYS AND DOTTED CRESCENTS     𑗌
U+115CD  IN-SENTENCE PUNCTUATION  # SIDDHAM SECTION MARK WITH RAYS AND DOTTED DOUBLE CRESCENTS      𑗍
U+115CE  IN-SENTENCE PUNCTUATION  # SIDDHAM SECTION MARK WITH RAYS AND DOTTED TRIPLE CRESCENTS      𑗎
U+115CF  IN-SENTENCE PUNCTUATION  # SIDDHAM SECTION MARK DOUBLE RING        𑗏
U+115D0  IN-SENTENCE PUNCTUATION  # SIDDHAM SECTION MARK DOUBLE RING WITH RAYS      𑗐
U+115D1  IN-SENTENCE PUNCTUATION  # SIDDHAM SECTION MARK WITH DOUBLE CRESCENTS      𑗑
U+115D2  IN-SENTENCE PUNCTUATION  # SIDDHAM SECTION MARK WITH TRIPLE CRESCENTS      𑗒
U+115D3  IN-SENTENCE PUNCTUATION  # SIDDHAM SECTION MARK WITH QUADRUPLE CRESCENTS   𑗓
U+115D4  IN-SENTENCE PUNCTUATION  # SIDDHAM SECTION MARK WITH SEPTUPLE CRESCENTS    𑗔
U+115D5  IN-SENTENCE PUNCTUATION  # SIDDHAM SECTION MARK WITH CIRCLES AND RAYS      𑗕
U+115D6  IN-SENTENCE PUNCTUATION  # SIDDHAM SECTION MARK WITH CIRCLES AND TWO ENCLOSURES    𑗖
U+115D7  IN-SENTENCE PUNCTUATION  # SIDDHAM SECTION MARK WITH CIRCLES AND FOUR ENCLOSURES   𑗗
U+11641  IN-SENTENCE PUNCTUATION  # MODI DANDA      𑙁
U+11642  IN-SENTENCE PUNCTUATION  # MODI DOUBLE DANDA       𑙂
U+11643  IN-SENTENCE PUNCTUATION  # MODI ABBREVIATION SIGN  𑙃
U+1173C  IN-SENTENCE PUNCTUATION  # AHOM SIGN SMALL SECTION         𑜼
U+1173D  IN-SENTENCE PUNCTUATION  # AHOM SIGN SECTION       𑜽
U+1173E  IN-SENTENCE PUNCTUATION  # AHOM SIGN RULAI         𑜾
U+12470  IN-SENTENCE PUNCTUATION  # CUNEIFORM PUNCTUATION SIGN OLD ASSYRIAN WORD DIVIDER    𒑰
U+12471  IN-SENTENCE PUNCTUATION  # CUNEIFORM PUNCTUATION SIGN VERTICAL COLON       𒑱
U+12472  IN-SENTENCE PUNCTUATION  # CUNEIFORM PUNCTUATION SIGN DIAGONAL COLON       𒑲
U+12473  IN-SENTENCE PUNCTUATION  # CUNEIFORM PUNCTUATION SIGN DIAGONAL TRICOLON    𒑳
U+12474  IN-SENTENCE PUNCTUATION  # CUNEIFORM PUNCTUATION SIGN DIAGONAL QUADCOLON   𒑴
U+16A6E  IN-SENTENCE PUNCTUATION  # MRO DANDA       𖩮
U+16A6F  IN-SENTENCE PUNCTUATION  # MRO DOUBLE DANDA        𖩯
U+16AF5  SENTENCE END PUNCTUATION  # BASSA VAH FULL STOP     𖫵
U+16B37  IN-SENTENCE PUNCTUATION  # PAHAWH HMONG SIGN VOS THOM      𖬷
U+16B38  IN-SENTENCE PUNCTUATION  # PAHAWH HMONG SIGN VOS TSHAB CEEB        𖬸
U+16B39  IN-SENTENCE PUNCTUATION  # PAHAWH HMONG SIGN CIM CHEEM     𖬹
U+16B3A  IN-SENTENCE PUNCTUATION  # PAHAWH HMONG SIGN VOS THIAB     𖬺
U+16B3B  IN-SENTENCE PUNCTUATION  # PAHAWH HMONG SIGN VOS FEEM      𖬻
U+16B44  IN-SENTENCE PUNCTUATION  # PAHAWH HMONG SIGN XAUS  𖭄
U+1BC9F  SENTENCE END PUNCTUATION  # DUPLOYAN PUNCTUATION CHINOOK FULL STOP  𛲟
U+1DA87  IN-SENTENCE PUNCTUATION  # SIGNWRITING COMMA       𝪇
U+1DA88  SENTENCE END PUNCTUATION  # SIGNWRITING FULL STOP   𝪈
U+1DA89  IN-SENTENCE PUNCTUATION  # SIGNWRITING SEMICOLON   𝪉
U+1DA8A  IN-SENTENCE PUNCTUATION  # SIGNWRITING COLON       𝪊
U+1DA8B  IN-SENTENCE PUNCTUATION  # SIGNWRITING PARENTHESIS         𝪋

End Section

Section "Forbidden characters"

# TODO: Wavy dashes are not included. Is it correct?

U+0022  скобки и кавычки  # QUOTATION MARK  "
U+0028  скобки и кавычки  # LEFT PARENTHESIS        (       
U+0029  скобки и кавычки  # RIGHT PARENTHESIS       )       
U+002D  дефис  # HYPHEN-MINUS    -
U+002F  косой слеш  # SOLIDUS         /
U+003C  уголок  # LESS-THAN SIGN  <
U+003E  уголок  # GREATER-THAN SIGN       >
U+005B  скобки и кавычки  # LEFT SQUARE BRACKET     [       
U+005C  косой слеш  # REVERSE SOLIDUS         \
U+005D  скобки и кавычки  # RIGHT SQUARE BRACKET    ]       
U+007B  скобки и кавычки  # LEFT CURLY BRACKET      {       
U+007C  вертикальный слеш  # VERTICAL LINE   |
U+007D  скобки и кавычки  # RIGHT CURLY BRACKET     }       
U+00AB  скобки и кавычки  # LEFT-POINTING DOUBLE ANGLE QUOTATION MARK       «       
U+00BB  скобки и кавычки  # RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK      »       
U+058A  дефис  # ARMENIAN HYPHEN         ֊
U+0F3A  скобки и кавычки  # TIBETAN MARK GUG RTAGS GYON     ༺       
U+0F3B  скобки и кавычки  # TIBETAN MARK GUG RTAGS GYAS     ༻       
U+0F3C  скобки и кавычки  # TIBETAN MARK ANG KHANG GYON     ༼       
U+0F3D  скобки и кавычки  # TIBETAN MARK ANG KHANG GYAS     ༽       
U+1400  дефис  # CANADIAN SYLLABICS HYPHEN       ᐀
U+169B  скобки и кавычки  # OGHAM FEATHER MARK      ᚛       
U+169C  скобки и кавычки  # OGHAM REVERSED FEATHER MARK     ᚜       
U+1806  дефис  # MONGOLIAN TODO SOFT HYPHEN      ᠆
U+2010  дефис  # HYPHEN  ‐
U+2011  дефис  # NON-BREAKING HYPHEN     ‑
U+2012  короткое тире  # FIGURE DASH     ‒
U+2013  короткое тире  # EN DASH         –
U+2014  длинное тире  # EM DASH         —
U+2018  скобки и кавычки  # LEFT SINGLE QUOTATION MARK      ‘       
U+2019  скобки и кавычки  # RIGHT SINGLE QUOTATION MARK     ’       
U+201A  скобки и кавычки  # SINGLE LOW-9 QUOTATION MARK     ‚       
U+201B  скобки и кавычки  # SINGLE HIGH-REVERSED-9 QUOTATION MARK   ‛       
U+201C  скобки и кавычки  # LEFT DOUBLE QUOTATION MARK      “       
U+201D  скобки и кавычки  # RIGHT DOUBLE QUOTATION MARK     ”       
U+201E  скобки и кавычки  # DOUBLE LOW-9 QUOTATION MARK     „       
U+201F  скобки и кавычки  # DOUBLE HIGH-REVERSED-9 QUOTATION MARK   ‟       
U+2026  многоточие  # HORIZONTAL ELLIPSIS     …
U+2039  скобки и кавычки  # SINGLE LEFT-POINTING ANGLE QUOTATION MARK       ‹       
U+203A  скобки и кавычки  # SINGLE RIGHT-POINTING ANGLE QUOTATION MARK      ›       
U+2045  скобки и кавычки  # LEFT SQUARE BRACKET WITH QUILL  ⁅       
U+2046  скобки и кавычки  # RIGHT SQUARE BRACKET WITH QUILL         ⁆       
U+207D  скобки и кавычки  # SUPERSCRIPT LEFT PARENTHESIS    ⁽       
U+207E  скобки и кавычки  # SUPERSCRIPT RIGHT PARENTHESIS   ⁾       
U+208D  скобки и кавычки  # SUBSCRIPT LEFT PARENTHESIS      ₍       
U+208E  скобки и кавычки  # SUBSCRIPT RIGHT PARENTHESIS     ₎       
U+2308  скобки и кавычки  # LEFT CEILING    ⌈       
U+2309  скобки и кавычки  # RIGHT CEILING   ⌉       
U+230A  скобки и кавычки  # LEFT FLOOR      ⌊       
U+230B  скобки и кавычки  # RIGHT FLOOR     ⌋       
U+2329  скобки и кавычки  # LEFT-POINTING ANGLE BRACKET     〈       
U+232A  скобки и кавычки  # RIGHT-POINTING ANGLE BRACKET    〉       
U+2768  скобки и кавычки  # MEDIUM LEFT PARENTHESIS ORNAMENT        ❨       
U+2769  скобки и кавычки  # MEDIUM RIGHT PARENTHESIS ORNAMENT       ❩       
U+276A  скобки и кавычки  # MEDIUM FLATTENED LEFT PARENTHESIS ORNAMENT      ❪       
U+276B  скобки и кавычки  # MEDIUM FLATTENED RIGHT PARENTHESIS ORNAMENT     ❫       
U+276C  скобки и кавычки  # MEDIUM LEFT-POINTING ANGLE BRACKET ORNAMENT     ❬       
U+276D  скобки и кавычки  # MEDIUM RIGHT-POINTING ANGLE BRACKET ORNAMENT    ❭       
U+276E  скобки и кавычки  # HEAVY LEFT-POINTING ANGLE QUOTATION MARK ORNAMENT       ❮       
U+276F  скобки и кавычки  # HEAVY RIGHT-POINTING ANGLE QUOTATION MARK ORNAMENT      ❯       
U+2770  скобки и кавычки  # HEAVY LEFT-POINTING ANGLE BRACKET ORNAMENT      ❰       
U+2771  скобки и кавычки  # HEAVY RIGHT-POINTING ANGLE BRACKET ORNAMENT     ❱       
U+2772  скобки и кавычки  # LIGHT LEFT TORTOISE SHELL BRACKET ORNAMENT      ❲       
U+2773  скобки и кавычки  # LIGHT RIGHT TORTOISE SHELL BRACKET ORNAMENT     ❳       
U+2774  скобки и кавычки  # MEDIUM LEFT CURLY BRACKET ORNAMENT      ❴       
U+2775  скобки и кавычки  # MEDIUM RIGHT CURLY BRACKET ORNAMENT     ❵       
U+27C5  скобки и кавычки  # LEFT S-SHAPED BAG DELIMITER     ⟅       
U+27C6  скобки и кавычки  # RIGHT S-SHAPED BAG DELIMITER    ⟆       
U+27E6  скобки и кавычки  # MATHEMATICAL LEFT WHITE SQUARE BRACKET  ⟦       
U+27E7  скобки и кавычки  # MATHEMATICAL RIGHT WHITE SQUARE BRACKET         ⟧       
U+27E8  скобки и кавычки  # MATHEMATICAL LEFT ANGLE BRACKET         ⟨       
U+27E9  скобки и кавычки  # MATHEMATICAL RIGHT ANGLE BRACKET        ⟩       
U+27EA  скобки и кавычки  # MATHEMATICAL LEFT DOUBLE ANGLE BRACKET  ⟪       
U+27EB  скобки и кавычки  # MATHEMATICAL RIGHT DOUBLE ANGLE BRACKET         ⟫       
U+27EC  скобки и кавычки  # MATHEMATICAL LEFT WHITE TORTOISE SHELL BRACKET  ⟬       
U+27ED  скобки и кавычки  # MATHEMATICAL RIGHT WHITE TORTOISE SHELL BRACKET         ⟭       
U+27EE  скобки и кавычки  # MATHEMATICAL LEFT FLATTENED PARENTHESIS         ⟮       
U+27EF  скобки и кавычки  # MATHEMATICAL RIGHT FLATTENED PARENTHESIS        ⟯       
U+2983  скобки и кавычки  # LEFT WHITE CURLY BRACKET        ⦃       
U+2984  скобки и кавычки  # RIGHT WHITE CURLY BRACKET       ⦄       
U+2985  скобки и кавычки  # LEFT WHITE PARENTHESIS  ⦅       
U+2986  скобки и кавычки  # RIGHT WHITE PARENTHESIS         ⦆       
U+2987  скобки и кавычки  # Z NOTATION LEFT IMAGE BRACKET   ⦇       
U+2988  скобки и кавычки  # Z NOTATION RIGHT IMAGE BRACKET  ⦈       
U+2989  скобки и кавычки  # Z NOTATION LEFT BINDING BRACKET         ⦉       
U+298A  скобки и кавычки  # Z NOTATION RIGHT BINDING BRACKET        ⦊       
U+298B  скобки и кавычки  # LEFT SQUARE BRACKET WITH UNDERBAR       ⦋       
U+298C  скобки и кавычки  # RIGHT SQUARE BRACKET WITH UNDERBAR      ⦌       
U+298D  скобки и кавычки  # LEFT SQUARE BRACKET WITH TICK IN TOP CORNER     ⦍       
U+298E  скобки и кавычки  # RIGHT SQUARE BRACKET WITH TICK IN BOTTOM CORNER         ⦎       
U+298F  скобки и кавычки  # LEFT SQUARE BRACKET WITH TICK IN BOTTOM CORNER  ⦏       
U+2990  скобки и кавычки  # RIGHT SQUARE BRACKET WITH TICK IN TOP CORNER    ⦐       
U+2991  скобки и кавычки  # LEFT ANGLE BRACKET WITH DOT     ⦑       
U+2992  скобки и кавычки  # RIGHT ANGLE BRACKET WITH DOT    ⦒       
U+2993  скобки и кавычки  # LEFT ARC LESS-THAN BRACKET      ⦓       
U+2994  скобки и кавычки  # RIGHT ARC GREATER-THAN BRACKET  ⦔       
U+2995  скобки и кавычки  # DOUBLE LEFT ARC GREATER-THAN BRACKET    ⦕       
U+2996  скобки и кавычки  # DOUBLE RIGHT ARC LESS-THAN BRACKET      ⦖       
U+2997  скобки и кавычки  # LEFT BLACK TORTOISE SHELL BRACKET       ⦗       
U+2998  скобки и кавычки  # RIGHT BLACK TORTOISE SHELL BRACKET      ⦘       
U+29D8  скобки и кавычки  # LEFT WIGGLY FENCE       ⧘       
U+29D9  скобки и кавычки  # RIGHT WIGGLY FENCE      ⧙       
U+29DA  скобки и кавычки  # LEFT DOUBLE WIGGLY FENCE        ⧚       
U+29DB  скобки и кавычки  # RIGHT DOUBLE WIGGLY FENCE       ⧛       
U+29FC  скобки и кавычки  # LEFT-POINTING CURVED ANGLE BRACKET      ⧼       
U+29FD  скобки и кавычки  # RIGHT-POINTING CURVED ANGLE BRACKET     ⧽       
U+2E02  скобки и кавычки  # LEFT SUBSTITUTION BRACKET       ⸂       
U+2E03  скобки и кавычки  # RIGHT SUBSTITUTION BRACKET      ⸃       
U+2E04  скобки и кавычки  # LEFT DOTTED SUBSTITUTION BRACKET        ⸄       
U+2E05  скобки и кавычки  # RIGHT DOTTED SUBSTITUTION BRACKET       ⸅       
U+2E09  скобки и кавычки  # LEFT TRANSPOSITION BRACKET      ⸉       
U+2E0A  скобки и кавычки  # RIGHT TRANSPOSITION BRACKET     ⸊       
U+2E0C  скобки и кавычки  # LEFT RAISED OMISSION BRACKET    ⸌       
U+2E0D  скобки и кавычки  # RIGHT RAISED OMISSION BRACKET   ⸍       
U+2E1A  дефис  # HYPHEN WITH DIAERESIS   ⸚
U+2E1C  скобки и кавычки  # LEFT LOW PARAPHRASE BRACKET     ⸜       
U+2E1D  скобки и кавычки  # RIGHT LOW PARAPHRASE BRACKET    ⸝       
U+2E20  скобки и кавычки  # LEFT VERTICAL BAR WITH QUILL    ⸠       
U+2E21  скобки и кавычки  # RIGHT VERTICAL BAR WITH QUILL   ⸡       
U+2E22  скобки и кавычки  # TOP LEFT HALF BRACKET   ⸢       
U+2E23  скобки и кавычки  # TOP RIGHT HALF BRACKET  ⸣       
U+2E24  скобки и кавычки  # BOTTOM LEFT HALF BRACKET        ⸤       
U+2E25  скобки и кавычки  # BOTTOM RIGHT HALF BRACKET       ⸥       
U+2E26  скобки и кавычки  # LEFT SIDEWAYS U BRACKET         ⸦       
U+2E27  скобки и кавычки  # RIGHT SIDEWAYS U BRACKET        ⸧       
U+2E28  скобки и кавычки  # LEFT DOUBLE PARENTHESIS         ⸨       
U+2E29  скобки и кавычки  # RIGHT DOUBLE PARENTHESIS        ⸩       
U+2E3A  длинное тире  # TWO-EM DASH     ⸺
U+2E3B  длинное тире  # THREE-EM DASH   ⸻
U+2E40  дефис  # DOUBLE HYPHEN   ⹀
U+2E42  скобки и кавычки  # DOUBLE LOW-REVERSED-9 QUOTATION MARK    ⹂       
U+3008  скобки и кавычки  # LEFT ANGLE BRACKET      〈       
U+3009  скобки и кавычки  # RIGHT ANGLE BRACKET     〉       
U+300A  скобки и кавычки  # LEFT DOUBLE ANGLE BRACKET       《       
U+300B  скобки и кавычки  # RIGHT DOUBLE ANGLE BRACKET      》       
U+300C  скобки и кавычки  # LEFT CORNER BRACKET     「       
U+300D  скобки и кавычки  # RIGHT CORNER BRACKET    」       
U+300E  скобки и кавычки  # LEFT WHITE CORNER BRACKET       『       
U+300F  скобки и кавычки  # RIGHT WHITE CORNER BRACKET      』       
U+3010  скобки и кавычки  # LEFT BLACK LENTICULAR BRACKET   【       
U+3011  скобки и кавычки  # RIGHT BLACK LENTICULAR BRACKET  】       
U+3014  скобки и кавычки  # LEFT TORTOISE SHELL BRACKET     〔       
U+3015  скобки и кавычки  # RIGHT TORTOISE SHELL BRACKET    〕       
U+3016  скобки и кавычки  # LEFT WHITE LENTICULAR BRACKET   〖       
U+3017  скобки и кавычки  # RIGHT WHITE LENTICULAR BRACKET  〗       
U+3018  скобки и кавычки  # LEFT WHITE TORTOISE SHELL BRACKET       〘       
U+3019  скобки и кавычки  # RIGHT WHITE TORTOISE SHELL BRACKET      〙       
U+301A  скобки и кавычки  # LEFT WHITE SQUARE BRACKET       〚       
U+301B  скобки и кавычки  # RIGHT WHITE SQUARE BRACKET      〛       
U+301D  скобки и кавычки  # REVERSED DOUBLE PRIME QUOTATION MARK    〝       
U+301E  скобки и кавычки  # DOUBLE PRIME QUOTATION MARK     〞       
U+301F  скобки и кавычки  # LOW DOUBLE PRIME QUOTATION MARK         〟       
U+30A0  дефис  # KATAKANA-HIRAGANA DOUBLE HYPHEN         ゠
U+FD3E  скобки и кавычки  # ORNATE LEFT PARENTHESIS         ﴾       
U+FD3F  скобки и кавычки  # ORNATE RIGHT PARENTHESIS        ﴿       
U+FE17  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL LEFT WHITE LENTICULAR BRACKET    ︗       
U+FE18  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL RIGHT WHITE LENTICULAR BRAKCET   ︘       
U+FE35  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL LEFT PARENTHESIS         ︵       
U+FE36  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL RIGHT PARENTHESIS        ︶       
U+FE37  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL LEFT CURLY BRACKET       ︷       
U+FE38  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL RIGHT CURLY BRACKET      ︸       
U+FE39  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL LEFT TORTOISE SHELL BRACKET      ︹       
U+FE3A  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL RIGHT TORTOISE SHELL BRACKET     ︺       
U+FE3B  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL LEFT BLACK LENTICULAR BRACKET    ︻       
U+FE3C  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL RIGHT BLACK LENTICULAR BRACKET   ︼       
U+FE3D  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL LEFT DOUBLE ANGLE BRACKET        ︽       
U+FE3E  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL RIGHT DOUBLE ANGLE BRACKET       ︾       
U+FE3F  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL LEFT ANGLE BRACKET       ︿       
U+FE40  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL RIGHT ANGLE BRACKET      ﹀       
U+FE41  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL LEFT CORNER BRACKET      ﹁       
U+FE42  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL RIGHT CORNER BRACKET     ﹂       
U+FE43  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL LEFT WHITE CORNER BRACKET        ﹃       
U+FE44  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL RIGHT WHITE CORNER BRACKET       ﹄       
U+FE47  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL LEFT SQUARE BRACKET      ﹇       
U+FE48  скобки и кавычки  # PRESENTATION FORM FOR VERTICAL RIGHT SQUARE BRACKET     ﹈       
U+FE58  длинное тире  # SMALL EM DASH   ﹘
U+FE59  скобки и кавычки  # SMALL LEFT PARENTHESIS  ﹙       
U+FE5A  скобки и кавычки  # SMALL RIGHT PARENTHESIS         ﹚       
U+FE5B  скобки и кавычки  # SMALL LEFT CURLY BRACKET        ﹛       
U+FE5C  скобки и кавычки  # SMALL RIGHT CURLY BRACKET       ﹜       
U+FE5D  скобки и кавычки  # SMALL LEFT TORTOISE SHELL BRACKET       ﹝       
U+FE5E  скобки и кавычки  # SMALL RIGHT TORTOISE SHELL BRACKET      ﹞       
U+FE63  дефис  # SMALL HYPHEN-MINUS      ﹣
U+FF02  скобки и кавычки  # FULLWIDTH QUOTATION MARK        ＂
U+FF08  скобки и кавычки  # FULLWIDTH LEFT PARENTHESIS      （       
U+FF09  скобки и кавычки  # FULLWIDTH RIGHT PARENTHESIS     ）       
U+FF0D  дефис  # FULLWIDTH HYPHEN-MINUS  －
U+FF3B  скобки и кавычки  # FULLWIDTH LEFT SQUARE BRACKET   ［       
U+FF3D  скобки и кавычки  # FULLWIDTH RIGHT SQUARE BRACKET  ］       
U+FF5B  скобки и кавычки  # FULLWIDTH LEFT CURLY BRACKET    ｛       
U+FF5D  скобки и кавычки  # FULLWIDTH RIGHT CURLY BRACKET   ｝       
U+FF5F  скобки и кавычки  # FULLWIDTH LEFT WHITE PARENTHESIS        ｟       
U+FF60  скобки и кавычки  # FULLWIDTH RIGHT WHITE PARENTHESIS       ｠       
U+FF62  скобки и кавычки  # HALFWIDTH LEFT CORNER BRACKET   ｢       
U+FF63  скобки и кавычки  # HALFWIDTH RIGHT CORNER BRACKET  ｣       

End Section
