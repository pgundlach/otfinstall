require "helper"

require "delegate"
require "fileutils"


class Family < DelegateClass(Array)
  def initialize
    @family=[]
    super(@family)
  end
  def parent(elt)
    ancestor = @family.find do |m|
      m.elt==elt
    end
    return nil unless ancestor
    @family.find do |m|
      m.elt == ancestor.parent
    end
  end
  def elts
    @family.collect do |m|
      m.elt
    end
  end
end
class Member
  attr_accessor :elt
  attr_accessor :parent
  def initialize(elt,parent)
    @elt=elt
    @parent=parent
  end
end


class LTXFont
  attr_accessor :weight_width
  attr_accessor :texname
  attr_accessor :shape
  attr_accessor :name
  def to_s
    "#{@name} {#{@weight_width}}{#{@shape}}"
  end
end


class OTFInstall
  attr_accessor :vendor
  attr_accessor :collection
  attr_accessor :basedir
  # if set, the otf will be found in vendor/collection
  attr_accessor :fontbase

  def initialize
    @collection = nil
    @vendor = nil
    @basedir = nil
    @fontbase = nil

    @ltxname = {
      "t1" => "T1",
      "ts1" => "TS1",
      "lgr" => "LGR",
      "ot1" => "OT1",
    }
    @maplines = []
    @fonts=[]
  end

  def check_info
    raise "collection not set" unless @collection
    raise "vendor not set" unless @vendor
    raise "basedir not set" unless @basedir
  end

  def dir(what)
    check_info
    case what
    when :tfm
      FileUtils::mkdir_p "#{@basedir}/fonts/tfm/#{@vendor}/#{@collection}"
    when :vf
      FileUtils::mkdir_p "#{@basedir}/fonts/vf/#{@vendor}/#{@collection}"
    when :pl
      FileUtils::mkdir_p "#{@basedir}/fonts/pl/#{@vendor}/#{@collection}"
    when :vpl
      FileUtils::mkdir_p "#{@basedir}/fonts/vpl/#{@vendor}/#{@collection}"
    when :enc
      FileUtils::mkdir_p "#{@basedir}/fonts/enc/dvips/#{@vendor}"
    when :t1
      FileUtils::mkdir_p "#{@basedir}/fonts/type1/#{@vendor}/#{@collection}"
    when :truetype
      FileUtils::mkdir_p "#{@basedir}/fonts/truetype/#{@vendor}/#{@collection}"
    when :map
      FileUtils::mkdir_p "#{@basedir}/fonts/map/pdftex"
      "#{@basedir}/fonts/map/pdftex/#{@collection}.map"
    when :sty
      FileUtils::mkdir_p "#{@basedir}/tex/latex/#{@vendor}"
      "#{@basedir}/tex/latex/#{@vendor}/#{@collection}.sty"
    when :ltxfd
      FileUtils::mkdir_p "#{@basedir}/tex/latex/#{@vendor}/#{@collection}"
    when :ltxexample
      FileUtils::mkdir_p "#{@basedir}/tex/latex/example"
      "#{@basedir}/tex/latex/example/#{@collection}.tex"
    else
      raise
    end
  end

  def install(encoding)
    args=[]
    args << "--tfm-directory=#{dir :tfm}"
    args << "--vf-directory=#{dir :vf}"
    args << "--pl-directory=#{dir :pl}"
    args << "--vpl-directory=#{dir :vpl}"
    args << "--encoding-directory=#{dir :enc}"
    args << "--type1-directory=#{dir :t1}"
    args << "--truetype-directory=#{dir :truetype}"
    args << "--no-updmap"
    args << "--encoding=#{encoding}"
    args
  end

  def set_default_value(value,default,warn=true)
    x = if @otfinstr.instance_variables.member?("@#{value}")
      @otfinstr.instance_variable_get("@#{value}")
    else
      puts "warning: #{value} not set, using #{default.inspect}" if warn
      default
    end
    self.instance_variable_set("@#{value}",x)
  end


  def read_otfinstr(path)
    @otfinstr=OInst.load(path)

    # set some default values
    set_default_value("collection", "otfinstall")
    set_default_value("vendor",     "otfinstall")
    set_default_value("variants",  ["default"]  )
    set_default_value("encodings", ["t1"]       )
    set_default_value("style",      "serif"     )

    fontdir = @fontbase ? File.join(@fontbase,vendor,collection) : ""

    iv = @otfinstr.instance_variables

    @collection = @otfinstr.instance_variable_get(iv.delete("@collection"))
    @vendor     = @otfinstr.instance_variable_get(iv.delete("@vendor"))
    @encodings  = @otfinstr.instance_variable_get(iv.delete("@encodings"))
    @variants   = @otfinstr.instance_variable_get(iv.delete("@variants"))
    @style      = @otfinstr.instance_variable_get(iv.delete("@style"))

    iv.each do |font|
      @fonts << f = LTXFont.new
      f.name=@otfinstr.instance_variable_get(font)
      case font
      when "@regular"
        f.weight_width = :m
        f.shape  = :n
        @fonts << sc = LTXFont.new
        sc.name = f.name
        sc.weight_width = :m
        sc.shape = :sc
      when "@bold"
        f.weight_width = :b
        f.shape  = :n
        @fonts << sc = LTXFont.new
        sc.name = f.name
        sc.weight_width = :b
        sc.shape = :sc
      when "@italic"
        f.weight_width = :m
        f.shape  = :it
      when "@bolditalic"
        f.weight_width = :b
        f.shape  = :it
      end
    end

    @encodings.each do |encoding|
      @fonts.each do |f|
        install_font(f,encoding)
      end
      write_fd(encoding)
    end

    write_sty

    @maplines << "% map file ends here"
    @maplines << ""
    File.open(dir(:map),"w") do |f|
      f << @maplines.join("\n")
    end

  end

  def write_sty
    sty = []
    sty << "\\ProvidesPackage{#{@collection}}"
    sty << "\\pdfmapfile{+#{@collection}.map}"
    case @style
    when "serif"
      sty << "\\renewcommand\\rmdefault{#{@collection}}"
    when "sans"
      sty << "\\renewcommand\\sfdefault{#{@collection}}"
    end
    File.open(dir(:sty),"w") do |f|
      f << sty.join("\n")
    end
  end
  def write_fd(encoding)
    filename="#{@ltxname[encoding]}#{@collection}.fd".downcase
    fd = []
    fd << "\\ProvidesFile{#{filename}}"
    fd << "\\DeclareFontFamily{#{@ltxname[encoding]}}{#{@collection}}{}"

    weight_widths = Family.new
    weight_widths << Member.new(:m,nil)
    weight_widths << Member.new(:l,:m)
    weight_widths << Member.new(:mc,:m)
    weight_widths << Member.new(:b,:m)
    weight_widths << Member.new(:bx,:b)
    weight_widths << Member.new(:bc,:b)
    weight_widths << Member.new(:eb,:b)

    shapes=Family.new
    shapes << Member.new(:n,nil)
    shapes << Member.new(:sc,:n)
    shapes << Member.new(:it,:n)
    shapes << Member.new(:sl,:it)

    fontshapes={}

    weight_widths.elts.each do |weight_width|
      shapes.elts.each do |shape|
        fontshapes["#{weight_width}/#{shape}"] = if par=weight_widths.parent(weight_width)
          "ssub * #{@collection}/#{par.elt}/#{shape}"
        else
          shp = shapes.parent(shape) && shapes.parent(shape).elt  || shape
          "ssub * #{@collection}/#{weight_width}/#{shp}"
        end
      end
    end
    @fonts.each do |font|
      fontshapes["#{font.weight_width}/#{font.shape}"] = "#{font.texname}"
    end

    unless fontshapes['m/n']
      puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!\nWarnung: normal (m/n) ist nicht definiert, das wird zu einer Endlosschleife führen!\n!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    end

    weight_widths.elts.each do |weight_width|
      shapes.elts.each do |shape|
        fd << "\\DeclareFontShape{#{@ltxname[encoding]}}{#{@collection}}{#{weight_width}}{#{shape}}{  <-> #{fontshapes["#{weight_width}/#{shape}"]}}{}"
      end
    end

    fd << "% fd file ends here"
    fd << ""

    File.open(File.join(dir(:ltxfd),filename),"w") do |f|
      f << fd.join("\n")
    end
  end
  def install_font(font,encoding)
    args = install(encoding)
    args << "\"#{@vendor}/#{@collection}/#{font.name}\""
    if font.shape == :sc
      args << "-fsmcp"
    end
    args << "-fliga"
    args << "-fkern"
    args << "-fonum"
    cmdline = "otftotfm #{args.join(" ")} 2> otfinstall.log"
    puts cmdline
    mapline = `#{cmdline}`.chomp
    @maplines << mapline
    font.texname=get_tex_name(mapline)
  end

  def get_tex_name(mapline)
    # the tex relevant name is the first part in the mapline
    mapline.split[0].chomp('--base') if mapline[0]
  end

end