require "net/https"
require "json"
require "open-uri"
require "io/console"
require "colorize"
require "qiita_org/search_conf_path.rb"

class QiitaGet
  def initialize(mode, id)
    @mode = mode
    @get_id = id
    search = SearchConfPath.new(Dir.pwd, Dir.home)
    @conf_dir = search.search_conf_path()
  end

  # set config
  def set_config()
    conf_path = File.join(@conf_dir, ".qiita.conf")
    conf = JSON.load(File.read(conf_path))
    @access_token = conf["access_token"]
    @teams_url = conf["teams_url"]
  end

  # select path
  def select_path()
    case @mode
    when "teams"
      @qiita = @teams_url
      @path = "api/v2/items?page=1&per_page=100"
    else
      @qiita = "https://qiita.com/"
      @path = "api/v2/authenticated_user/items?page=1&per_page=100"
    end
  end

  # access qiita
  def access_qiita()
    uri = URI.parse(@qiita + @path)

    headers = { "Authorization" => "Bearer #{@access_token}",
      "Content-Type" => "application/json" }

    response = URI.open(
                        "#{uri}",
                        "Authorization" => "#{headers["Authorization"]}",
                        )
    @items = JSON.parse(response.read)
  end

  # select report
  def select_report()
    @items.each do |item|
      p "title: #{item["title"]}"
      p "Do you gets it?(y/n), ('e' to exit)"
      p ans = STDIN.getch

      next if ans == "n"
      if ans == "e"
        break
      end
      if ans == "y"
        p @title = item["title"] #.gsub(/ |\(|\)/, " " => "_", "(" => "", ")" => "")
        @id = item["id"]
        @author = item["user"]["id"]
        @tags = []
        @private = item["private"]
        item["tags"].each do |tag|
          @tags << tag["name"]
        end
        p filename = "#{@id}.md"
        File.write(filename, item["body"])
        convert_md_to_org()
        write_header_on_org()
        puts_massage_and_delete_md()
      end
    end
  end

  # id.md -> id.org
  def convert_md_to_org()
    system "pandoc #{@id}.md -o #{@id}.org"
  end

  # set header
  def set_header()
    head = <<"EOS"
#+OPTIONS: ^:{}
#+STARTUP: indent nolineimages
#+TITLE: #{@title}
#+AUTHOR: #{@author}
#+EMAIL:
#+LANGUAGE:  jp
# +OPTIONS:   H:4 toc:t num:2
#+OPTIONS:   toc:nil
#+TAG: #{@tags.join(", ")}
#+SETUPFILE: ~/.emacs.d/org-mode/theme-readtheorg.setup\n
EOS

    return head
  end

  #check mode
  def check_mode()
    if @private
      @mode = "private"
    else
      @mode = "public"
    end
  end

  # write header
  def write_header_on_org()
    head = set_header()

    check_mode() if @mode != "teams"

    conts = File.read("#{@id}.org")
    File.write("#{@id}.org", "#+qiita_#{@mode}: #{@id}\n" + head + conts)
  end

  # see massage and delete id.md
  def puts_massage_and_delete_md()
    puts "created #{@id}.org".green
    system "rm -f #{@id}.md"
  end

  def get_id_report()
    case @mode
    when "teams"
      @qiita = @teams_url
    else
      @qiita = "https://qiita.com/"
    end
    @path = "api/v2/items/#{@get_id}"

    access_qiita()

    @title = @items["title"]
    @id = @items["id"]
    @author = @items["user"]["id"]
    @tags = []
    @private = @items["private"]
    @items["tags"].each do |tag|
      @tags << tag["name"]
    end
    p filename = "#{@id}.md"
    File.write(filename, @items["body"])
    convert_md_to_org()
    write_header_on_org()
    puts_massage_and_delete_md()
  end

  def run()
    set_config()
    if @get_id == nil
      select_path()
      access_qiita()
      select_report()
    else
      get_id_report()
    end
  end
end
