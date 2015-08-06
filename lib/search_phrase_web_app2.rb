# encoding: UTF-8
require 'sinatra/base'
require 'expiring_hash_map'

#          <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
#           <hr style="height: 1px"/>
#           <center><small><a href="<%=@source_code_url%>">Source code</a> | <a href="mailto:<%=@email%>">Contact me</a></small></center>
  #{env["SCRIPT_NAME"]}

class SearchPhraseWebApp < Sinatra::Application
  
  template :index do
    <<-HTML
    HTML
  end
  
  get '/' do
    redirect 'index.php'
  end
  
end