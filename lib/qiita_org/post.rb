# -*- coding: utf-8 -*-
#+begin_src ruby -n
require "net/https"
require "json"
require "command_line/global"
require "colorize"
require "qiita_org/md_converter_for_image"
require "qiita_org/set_config.rb"
require "qiita_org/error_message"
require "qiita_org/file_open.rb"

class QiitaPost
  def initialize(file, option, os)
    @src = file
    @option = (option == "qiita" || option == "open")? "public" : option
    @os = os
  end

  public
  def get_title_tags(conts)
    m = conts.match(/\#\+(TITLE|title|Title): (.+)/)
    @title = m ?  m[2] : "テスト"
    @tags = if m = conts.match(/\#\+(TAG|tag|Tag|tags|TAGS|Tags): (.+)/)
              #if m[2].count(",") >= 5
               # puts "The maximum number of tag is five. Please delete some tags.".red
                #exit
              #end
              ErrorMessage.new().many_tags_error(m[2])
              m[2].split(",").inject([]) do |l, c|
                 l << { name: c.strip } #, versions: []}
              end
            else
              [{ name: "hoge" }] #, versions: [] }]
            end
    p @tags
    return @title, @tags
  end

  # src.org -> src.md
  def convert_org_to_md()
    command = "emacs #{@src} --batch -l #{@ox_qmd_load_path} -f org-qmd-export-to-markdown --kill"
    res = command_line command
    #p res
    ErrorMessage.new().md_file_exists?(@src, res)
  end

  # add source path in md
  def add_source_path_in_md()
    @lines = File.readlines(@src.gsub(".org", ".md"))
    path = Dir.pwd.gsub(ENV["HOME"], "~")
    @lines << "\n\n------\n - **source** #{path}/#{@src}\n"
  end

  # patch or post selector by qiita_id
  def select_patch_or_post(conts, option)
    m = []
    patch = false
    if m = conts.match(/\#\+qiita_#{option}: (.+)/)
      qiita_id = m[1]
      patch = true
    else
      qiita_id = ""
    end
    return qiita_id, patch
  end

  # check twitter post
  def select_twitter(conts, option)
    option == "public" && conts.match?(/^\#\+twitter:\s*on$/i)
  end

  def select_option(option)
    qiita = (option == "teams")? @teams_url : "https://qiita.com/"
    #qiita = (option == "teams")? "https://nishitani.qiita.com/" :
     # "https://qiita.com/"
    case option
    when "teams", "qiita", "public", "open"
      private = false
    when nil, "private"
      private = true
    else
      raise "Unknown option: #{option}".red
    end
    return [qiita, private]
  end

  # qiita post
  def qiita_post()
    params = {
      "body": @lines.join.gsub("\\\\![", "!["), #.gsub("\\\\", ""), #.gsub("\\", ""), #"# テスト",
      "private": @private,
      "title": @title,
      "tags": @tags,
      "tweet": @twitter,
    }

    if @patch
      @path = "api/v2/items/#{@qiita_id}"
    else
      @path = "api/v2/items"
    end
    p ["qiita", @qiita]
    p ["path", @path]
    p @qiita + @path
    uri = URI.parse(@qiita + @path)

    http_req = Net::HTTP.new(uri.host, uri.port)
    http_req.use_ssl = uri.scheme === "https"

    headers = { "Authorization" => "Bearer #{@access_token}",
                "Content-Type" => "application/json" }

    if @patch
      res = http_req.patch(uri.path, params.to_json, headers)
    else
      res = http_req.post(uri.path, params.to_json, headers)
    end

    ErrorMessage.new().qiita_post_error(res, @src.gsub(".org", ".md"))

    return res
  end

  # qiita return
  def get_and_print_qiita_return()
    p @res.message

    @res_body = JSON.parse(@res.body)
    @res_body.each do |key, cont|
      if key == "rendered_body" or key == "body"
        puts "%20s brabrabra..." % key
        next
      end
      print "%20s %s\n" % [key, cont]
    end
    #if @display == "suppress"
    #  puts @res_body["url"].green
    #end
  end

  # add qiita_id on src.org
  def add_qiita_id_on_org()
    @qiita_id = @res_body["id"]
    unless @patch
      File.write(@src, "#+qiita_#{@option}: #{@qiita_id}\n" + @conts)
    end
  end

  # open qiita
=begin
  def open_qiita()
    if @os == "mac"
      system "open # {@res_body["url"]}"
    elsif @os == "windows"
      system "explorer.exe # {@res_body["url"]}"
    else
      system "open # {@res_body["url"]}"
      system "xdg-open # {@res_body["url"]}"
    end
  end
=end

  def run()
    @conts = File.read(@src)
    @title, @tags = get_title_tags(@conts)
    @access_token, @teams_url, @display, @ox_qmd_load_path = SetConfig.new().set_config()

    if @option == "teams"
      ErrorMessage.new().teams_url_error(@teams_url)
    end

    convert_org_to_md()
    add_source_path_in_md()
    @lines = MdConverter.new().convert_for_image(@lines)
    @qiita_id, @patch = select_patch_or_post(@conts, @option)
    @twitter = select_twitter(@conts, @option)
    @qiita, @private = select_option(@option)
    @res = qiita_post()
    get_and_print_qiita_return()

    #open_qiita()
    FileOpen.new(@os).file_open(@res_body["url"]) if @display != "suppress"

    add_qiita_id_on_org()

    system "rm #{@src.gsub(".org", ".md")}"
  end
end

#+end_src
