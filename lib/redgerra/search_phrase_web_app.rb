# encoding: UTF-8
require 'sinatra/base'
require 'expiring_hash_map'
require 'redgerra/search_phrase'
require 'web_search_error'

module Redgerra

  # 
  # Web-interface for Redgerra::search_phrase().
  # 
  class SearchPhraseWebApp < Sinatra::Application
    
    # 
    # +search_web+ is +search_web+ argument for Redgerra::search_phrase().
    # 
    # +new_web_search_browser+ is a Proc returning a new Watir::Browser eligible
    # for passing it to +search_web+.
    # 
    # +results_per_page+ is number of results to be shown until "More..."
    # button is displayed.
    # 
    # +cache_lifetime+ is how long +search+ results are cached for.
    # 
    def initialize(search_web, new_web_search_browser, results_per_page = 200, cache_lifetime = 30*60)
      super()
      @search_web = search_web
      @new_web_search_browser = new_web_search_browser
      @results_per_page = results_per_page
      @sessions = ExpiringHashMap.new(cache_lifetime) do |session|
        session.close()
      end
    end
    
    private
    
    APP_DIR = "#{File.dirname(__FILE__)}/search_phrase_web_app.d"
    
    set :views, "#{APP_DIR}/views"
    set :public_folder, "#{APP_DIR}/static"
    
    get "/" do
      redirect to "index.html", false
    end
    
    get "/index.html" do
      erb :index, locals: {
        sloch: (params[:"sloch"] || ""),
        
      }
    end
    
    get "/phrase" do
      # 
      sloch = params[:"sloch"]
      halt 400, "Sloch is not specified" if sloch.nil? or sloch.empty?
      offset = (params[:offset] || "0").to_i
      # 
      begin
        session[sloch].phrases[offset] || ""
      rescue WebSearchError => e
        halt 503, e.user_readable_message
      end
    end
    
    def session(sloch)
      @sessions[sloch] ||= Session.new(@search_web, @new_web_search_browser, sloch)
    end
    
    class Session
      
      def initialize(search_web, new_web_search_browser, sloch)
        @browser = new_web_search_browser.()
        @phrases = Redgerra::search_phrase(sloch, @search_web, @browser)
      end
      
      attr_reader :phrases
      
      def close()
        @browser.close()
      end
      
    end
    
  end

end
