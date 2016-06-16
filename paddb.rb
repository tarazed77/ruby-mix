#!/usr/bin/env ruby

# paddb
#
=begin

Graphical control program for address label printing, based on ruby-tk.  This
application has evolved from a simple label printer written originally in Fortran and
assembler for the IBM Portable PC in 1984 and later converted to C and assembler.  It
was moved to Linux in 1996 and recoded in C and Tcl/Tk.  Recoded in ruby and ruby-tk
in 2008, partly as an exercise in learning to use ruby.  An attempt to use fxruby
failed because FOX does not provide the same capabilities in the canvas widget as Tk
does and it would probably have entailed years of research to find a way to mimic the
Tk functionality, in particular mapping the canvas contents to a Postscript file.  
The same would probably be the case for other toolkits such as wx and GTK.

There are several problems which have never been adequately solved, such as 
registration and scaling or to put it another way; WYSIWYG was the goal but has not
been achieved.

The data associated with this script is a flat file database in info-type format
with entries formatted according to the example below.
paddb displays a list of names for a selected category and provides label printing
controls including a preview via an interactive canvas.  Addresses can be added,
edited, or removed.  Displayed data can be edited in place (and must be saved) or 
can be prrocessed through the editing function.

    @29 :publications
    date: 1999 Feb 26
    [data]
    I P C Business Press
    40 Bowling Green Lane
    London EC1R 0NE
    [notes]
    031 447 4063
    [end]

The first line is an arbitrary id number and a category name to be chosen by the user.
The notes section is optional.  The categories come from a preferences file 
paddb.yml in the user's .local/share/paddb directory.  See this example;

---
:addressfile: addresses
:defaultcat: friends
:font: Larabiefont,10
:category:
- Cate
- Christine
- addresses
- computers
- family
- finance
- friends
- labels
- offices
- opg
- publications
- thistle
- trimmers
- typefaces
:printer:
  :HP_Photosmart5520: okda
  :network_printer: okda
  :HP_Envy_4500: exo
  :file: file
:default: network_printer
:colours:
  :black: black
  :blue: blue
  :brown: brown
  :cyan: cyan
  :DarkGoldenrod: DarkGoldenrod
  :DarkGray: DarkGrey
  :green: '#33cc33'
  :grey44: grey44
  :magenta: magenta
  :midnight: MidnightBlue
  :OliveDrab: OliveDrab
  :orange: orange
  :pink: pink
  :purple: purple
  :red: '#bb4433'
  :SaddleBrown: SaddleBrown
  :SeaGreen: SeaGreen
  :SlateGray: SlateGrey
  :yellow: yellow
:odt: /home/lcl/Documents/labels

In the printer section the first column is a descriptive name for the printer
as it appears in the menu and the second column is the corresponding queue name.
"file" means that the only output is the postscript file in $HOME/tmp.

All reference files are to be found in $HOME/.local/share/paddb
e.g.
addresses      fontlist  newdata       paddbrc     repairs     Tk-families
addresses.bak  images    newfile       paddb.yaml  test.yml    tkfamilies_extended
addr.safe      missing   paddb.config  paddb.yml   tkfamilies

Categories are self-explanatory.

The colours list contains the colour selections for individual labels, a single 
colour only.  Each entry gives the menu label and either the standard X colour or 
an RGB value.

The program contains an addressbook function for printing out all the entries in a
particular category.

TODO: commandline functions to display or print labels(s) meeting search criteria, 
to generate a file in ODT format for a particular address, and a utility for managing
the fontfile.  There is a facility for adding image backgrounds to a label which needs
to be improved or else removed.

#
# Author : Len Lawrence (Edinburgh, UK) : tarazed25@gmail.com
# The very first version was written in Fortran and IBM assembler in 1984 for
# an IBM Portable PC and has undergone many changes. C+assembler in 1985
# called from DOS.  1993 saw a change from DOS to Linux, and C+Tcl/Tk.  C++ 
# and Tcl/Tk later then Ruby and ruby-tk.
#
# Version 9.2.13 : 2008 March 18
# Version 9.8.0  : 2011 Mar 18 : major overhaul and testing
# Version 9.9.2  : 2014 Jan 05 : introduced slot allocation
# Version 10.84  : 2015-07-09
=end

require 'rubygems'
require 'tk'
require 'tkextlib/tkimg/jpeg'
require 'tkextlib/tkimg/png'
require 'tkextlib/tkimg/xpm'
require 'date'
require 'yaml'
require "#{ENV['HOME']}/ruby/paddb/labelling"
require "#{ENV['HOME']}/ruby/paddb/postscript"
require "#{ENV['HOME']}/ruby/paddb/imagefactory"

Version = 'paddb 11.13'
Today   = (DateTime.now).to_s.slice( 0, 10 )
Home    = ARGV[0] ? ARGV[0] : Dir.home + "/.local/share/paddb/"

Panel   = 'grey88'
Set     = 'BlanchedAlmond'
Clear   = 'grey81'
# Canvas offsets for label icons in the page setup section
Offset  = 20
Yoff    = 4

Larabie = TkFont.new "{LarabieFont} {11} {normal} {normal}"
Small   = TkFont.new "{LarabieFont} {10} {normal} {normal}"
Large   = TkFont.new "{Helvetica} {22} {normal} {bold}"

Record  = Struct.new( :ref, :category, :date, :name, :serial, :data, :notes )

Env = { 'preview'      => nil,        'labels'       => nil,
        'grid'         => nil,        'griddle'      => nil,
        'page'         => nil,        'names'        => nil,
        'data'         => nil,        'notes'        => nil,
        'delete'       => nil,        'save'         => nil,
        'fontview'     => nil,        'newentry'     => nil,
        'editmode'     => 'new',      'category'     => ' ',
        'colour'       => 'black',    'disposition'  => '3x7',
        'Xfont'        => ' ',        'toggle'       => -1,
        'oldsheet'     => false,      'set'          => false,
        'gridlines'    => true,       'gridset'      => false,
        'setbutton'    => nil,        'clicklist'    => [ ],
        'colours'      => nil,        'photolist'    => [ ],
        'photocount'   => -1,         'photoselect'  => 0,
        'newgrid'      => nil,        'home'         => Home,
        'blank'        => true,       'new'          => true,
        'displayfont'  => ' ' }

Config = { 'colour'    => 'black',
           'font'      => 'Comic',
           'label'     => 'Comic',
           'xfont'     => ' ',
           'state'     => 0,
           'size'      => 12,
           'style'     => 'normal',
           'weight'    => 'normal',
           'setting'   => 0,
           'margin'    => 10,
           'yoff'      => -10 }

# Vertical registration
Registration = { '3x7'  => 0,
                 '2x7'  => 5,
                 '2x4'  => 2,
                 '5x13' => 0,
                 'long' => 0,
                 'envelope' => 0,
                 '4x8'  => 0 }
# Horizontal registration
Adjustment = { '3x7'  => -8,
               '2x7'  => -5,
               '2x4'  => -11,
               '5x13' => 0,
               'long' => 0,
               'envelope' => 0,
               '4x8'  => 0 }

home = ENV['HOME']
Add     = TkPhotoImage.new( 'file' => "#{home}/images/icons/media-record.png" )
Book    = TkPhotoImage.new( 'file' => "#{home}/images/icons/book.png" )
Catlist = TkPhotoImage.new( 'file' => "#{home}/images/icons/list.png" )
Clone   = TkPhotoImage.new( 'file' => "#{home}/images/icons/icon-1.png" )
Exit    = TkPhotoImage.new( 'file' => "#{home}/images/icons/close.png" )
Fill    = TkPhotoImage.new( 'file' => "#{home}/images/icons/view-grid.png" )
New     = TkPhotoImage.new( 'file' => "#{home}/images/icons/new.png" )
Printer = TkPhotoImage.new( 'file' => "#{home}/images/icons/picon.png" )

def readfontnames
  fontnames = [ ]
  filename = File.join( Home, "tkfamilies" )
  if File.exist?( filename ) then
    file = File.new( filename, 'r' )
    while line = file.gets
      fontnames << line.chomp
    end
    file.close  
  else
    fontnames = nil
  end
  fontnames
end
=begin
def readpscorrections
  repairs = [ ]
  filename = File.join( Home, "repairs" )
  if File.exist?( filename ) then
    file = File.new( filename, 'r' )
    while line = file.gets
      repairs << line.chomp.strip.split( ',' )
    end
    file.close  
  else
    repairs = nil
  end
  repairs
end
=end    
def abort ( warning ) 
  root = TkRoot.new
  root.title = "attention!"
  msgBox = Tk.messageBox(
    'type'    => "ok",  
    'icon'    => "error", 
    'title'   => "Please note",
    'message' => warning
  )
  exit( )
  Tk.mainloop
end

Families = readfontnames
if !::Families then
  abort( "Missing font names file.
Create a tkfamilies file in
paddb resource directory by
running the paddb-fonts utility." )
end
#Repairs  = readpscorrections

class Address

  attr_accessor :filename, :records, :record, :slot,
                :backcloth, :categories, :category_count,
                :category_index, :colours, :keylist, :default_category,
                :default_font, :printers, :default_printer, :odt

  def read_preferences
    # Read the preferences from the YAML file in .local/share/paddb
    # Some parameters must be defined; others have defaults but it is
    # not advisable to rely on defaults for printers or else output 
    # would always go to a file in /tmp.
    preferences = File.join( Home, "paddb.yml" )
    tree        = YAML.load_file preferences
    filename    = File.join( Home, tree[:addressfile] )
    categories  = tree[:category]
    category    = tree.fetch( :defaultcat, 'family' )
    typeface, size = tree[:font].split( ',' )
    fontstring  = "{#{typeface}} {#{size}} {normal} {normal}"
    font        = TkFont.new fontstring
    printers    = tree.fetch( :printer, [ 'file', 'file' ] )
    printer     = tree.fetch( :default, 'file' )
    colours     = tree[:colours]
    odt         = tree.fetch( :odt, ENV['HOME']+"/Documents" )
    underlay    = tree[:underlay]
    [ filename, category, font, printers, printer, categories,
      colours, odt, underlay ]
  end

  def readfile ( filename )
    # Load an address database
    file = File.new( filename, 'r' )
    backup = filename + '.bak'
    system "cp #{filename} #{backup}"
    rec = n = 0
    record = [ ]
    u = [ ]
    v = [ ]
    category_index = { }
    count = { }
    category = ""
    while ( line = file.gets ) do
      case
      when line[0] == '@' then
        buffer = line.chomp.split( ':' )
        zed = { }
        zed['ref'] = buffer[0].slice(1..-1).to_i
        ref = zed['ref'].to_i
        zed['category'] = category = buffer[1]
        data = notes = false
      when line =~ /date:/ then
        buffer = line.split( ':' )
        zed['date'] = buffer[1].lstrip
      when line =~ /\[data\]/ then
        n = 0
        data = true
        u.clear
      when line =~ /\[notes\]/ then
        data = false
        notes = true
        v.clear
      when line =~ /\[end\]/ then
        record[rec] = store_record( zed, u, v, notes )
        record[rec]['serial'] = rec
        update_category( record, rec, category_index, count )
        notes = false
        rec += 1
      else
        u.push line if data
        v.push line if notes
      end
    end
    file.close
    [ record, rec, category_index, count ]
  end

  def update_category ( record, rec, category_index, count )
    # Load the category name from the specified record and create a slot
    # for it in the category index if this is its first appearance and 
    # update or initialize the count for this category.  In addition place
    # the first line of the address and the associated record number in
    # the list for this category.  Note that new category names will not appear
    # in the menu list next time the program is run unless the yaml file is
    # updated manually.
    category = record[rec]['category']
    name = record[rec]['name']
    if category_index[category] then
      count[category] += 1
    else
      category_index[category] = [ ]
      count[category] = 1
    end
    j = count[category] - 1
    category_index[category][j] = [ name, rec ]
  end

  def findrecord ( ref )
    j = -1
    @record.each { |record| j += 1; break if record['ref'] == ref }
    j
  end
 
  def edit_cat ( record, newtype )
    old = record['category']
    record['category'] = newtype
    rec = findrecord record['ref']
    update_category( @record, rec, @category_index, @count )
  end

  def store_record ( values, u, v, notes )
    # Create a new address record from the passed data values and return
    # the reference.  The 'serial' field is given a null value which should 
    # be overwritten if the data is assigned a place in an array.
    zed = values     
    zed['data'] = Marshal.load( Marshal.dump( u ) )
    zed['notes'] = Marshal.load( Marshal.dump( v ) ) if notes
    zed['name'] = u[0].chomp
    pep = Marshal.load( Marshal.dump( zed ) )
    pip = ::Record.new( pep['ref'], pep['category'],
                        pep['date'], pep['name'], nil,
                        pep['data'], pep['notes'] )
    pip
  end

  def categorysort
    @category_index.each_key { |cat| @category_index[cat].sort! }
  end

  def markslots ( record )
    # Find maximum reference number in the database.  Record references are
    # always assigned sequentially as records are created so when records
    # are deleted there will be "holes" in the sequence.  This function
    # creates a marker array spanning the reference numbers with an extra
    # slot at the end and returns the maximum reference and the slot lookup
    # table; indexed on reference, with value 0 for free and 1 for in use.
    max = 0
    record.each do |entry|
      ref = entry['ref']
      max = ref if ref > max
    end
    # Establish lookup table
    slot = [ 0 ] * (max + 1)
    # Populate the table
    record.each { |entry| slot[entry['ref']] = 1 }
    [ max, slot ]
  end

  def initialize ( filename )
    @filename    = ''
    @filename    = filename if filename
    @printers    = { }
    @keylist     = { }
    f, @default_category, @default_font, @printers, @default_printer,
      @categories, @colours, @odt, @backcloth = read_preferences
    @filename    = f if @filename.empty?
    @category_index = { }
    @count          = { }
    @record, @records, @category_index, @count = readfile @filename
    categorysort
    @maxref, @slot = markslots @record
  end

  def getslot
    # Find an available reference number for a new record or add another
    i = 0
    @maxref.times { |n| i = n + 1; break if @slot[i] == 0 }    
    @maxref = i if i > @maxref
    i
  end

  def newrecord ( category, newdata, newnotes )
    # Store new record
    # "arbitrary" identifier
    newref = getslot
    # Create container for new data
    @record[@records] = { }
    # Update category index
    update_category( @record, @records, @category_index, @count )
    # Temporary reference to current record
    e = @record[@records]
    # Build the record
    e['ref'] = newref
    e['category'] = category
    e['date'] = ::Today
    e['data'] = [ ]
    e['notes'] = [ ]
    # Fill in the address elements
    newdata.each { |line| e['data'] << line }
    e['name'] = newdata[0].chomp
    # Copy the notes if there are any
    newnotes.each { |line| e['notes'] << line } if newnotes
    # Bump the record count
    @records += 1
    @records
  end

  def writefile ( file )
    newfile = File.new( file, 'w' )
    rec = 0
    @record.each { |record|
      if ( record['ref'] > 0 ) then
        newfile.puts( "@#{record['ref']} :#{record['category']}" )
        newfile.puts( "date: #{record['date']}" )
        newfile.puts( "\[data\]" )
        record['data'].each { |line| newfile.puts( line ) }
        if ( record['notes'] ) then
          newfile.puts( "\[notes\]" )
          record['notes'].each { |line| newfile.puts( line ) }
        end
        newfile.puts( "\[end\]" )
        rec += 1
      end
    }
    newfile.close
    rec
  end

  def getnames ( category )
    namelist = @category_index[category]
    namelist
  end

end

def closedown ( user )
  user.savetofile if user.changes
  exit
end

class User

  include Labelling
  extend  Labelling
  include Postscript
  extend  Postscript

  attr_accessor :bold, :bottom, :category, :catinfo, :countinfo, :changes,
                :config, :dateinfo, :device, :env, :example, :font, :fontex,
                :gap, :height, :help, :italic, :labeltext, :margin, :nameindex,
                :names, :namelist, :newgrid, :notepad, :nx, :ny, :paddb,
                :printer, :printerdefault, :printerqueue, :odt, :photo,
                :photonumber, :records,
                :record, :registration, :searchstring, :scratchpad, :size,
                :tempinfo, :typeface, :type, :underlay, :user, :wbg, :width,
                :window, :wwt, :xymax

  Scale = 0.27 / Xscale
  Tag   = 'zib'
  Ghost = 'ghost'

  # Change the background to the name list to a pattern of
  # alternating colours.
  def guidelines ( w, m, colours )
    toggle = 0
    k = m - 1
    0.upto( k ) { |i|
      w.itemconfigure( i, 'background'=>colours[toggle] )
      toggle = 1 - toggle
    }
  end

  def fontmenu ( user, flex )
    # Note that this is a tearoff menu, a practice which is frowned upon
    # by programming professionals.  In this case, and bearing in mind that
    # this whole program was designed around a personal need it seemed the
    # best way to display all the available fonts, which might be required
    # to be on screen continuously to allow experimenting with individual
    # address labels.  The alternative, to be implemented sometime, is a
    # top level window with a permanent menu.  What I did not need in this
    # case was a scrolling menu.  Users might want to have dozens of fonts
    # available.  Anybody who disagrees is free to modify the script.
    # There is of course the notion of too much choice and the rider that
    # the creation of a large collection increases program load time and
    # takes up extra space on the screen. 
    fontcount = ::Families.length
    n = fontcount / 3
    m = n + 1
    i = -1
    sample = nil
    z = nil
    fontlist = { }
    ::Families.each { |xyz| z = "{#{xyz.tr(" ","")}} {11} {normal} {normal}"
                      fontlist[xyz] = TkFont.new z
                    }
    fonts = TkMenuButton.new( flex ) do
      text         'font'
      font         user.font
      background   'grey36'
      foreground   'LemonChiffon'
      menu TkMenu.new( self ) {
        tearoff    true
        ::Families.each { |e| add 'command',
          { 'label' => e, 'font' => fontlist[e],
            'columnbreak' => ((i += 1) % m) > 0 ? 0 : 1,
            'command' => Proc.new { user.setfont( e )
                                    user.samplefont( e ) } }
        }
      }
      relief       'flat'
      pack         'side' => 'left'
    end
  end

  def setfont ( typeface )
    size   = @config['size']
    slant  = @config['style']
    weight = @config['weight']
    z = "{#{typeface}} {#{size}} {#{slant}} {#{weight}}"
    @config['label'] = font = TkFont.new( z )
    weight = @config['weight']
    @example.value = typeface + "  #{size}"
    @typeface = typeface
    z = "{#{typeface}} {12} {#{slant}} {#{weight}}"
    fontex = TkFont.new( z )
    @env['fontview'].configure( 'font' => fontex )
    @env['data'].configure( 'font' => fontex )
    @fontex = font
  end

  def setlabelsize
    @config['size'] = @size.value
    setfont( @typeface )
  end

  def setlabelcolour ( colour )
    @env['colour'] = colour
    @env['fontview'].configure( 'foreground' => colour )
    @env['data'].configure( 'foreground' => colour )
    @config['colour'] = colour
  end

  def updatelabelstyle
    bold = @bold.value.to_i
    italic = @italic.value.to_i
    @config['style'] = italic == 0 ? 'normal' : 'italic'
    @config['weight'] = bold == 0 ? 'normal' : 'bold'    
    @config['setting'] = bold + italic + italic
    setfont( @typeface )
  end

  #========================================================================

  @@counter = 0

  def reset_flags
    flag = @env['clicklist']
    0.upto( @xymax-1 ) { |i| flag[i] = 0 }
  end

  # Calculate coordinates for the Postscript page canvas and the
  # label icons canvas in the setupInkjet window.
  def calcxy ( disposition, f )
    puts "calcxy: f = #{f}"
    # disposition is a string of the form '<x>x<y>'; e.g. '3x7'
    # f is an empirical scaling factor
    xygrid = { }
    # Split the disposition string into x and y counts.
    xy = Disposition[disposition]
    # Obtain the label dimensions.
    labelsize = Labelsizes[disposition]
    @config['margin'] = labelsize[0] / 2
    @config['yoff'] = (labelsize[1] / 2) - 5
    # Populate the coordinate data structure.
    xygrid['x'] = nx = xy[0]
    xygrid['y'] = ny = xy[1]
    # Obtain an array of 4 element arrays from the Labelling module.
    # These represent opposing corners of the address spaces on the
    # Postscript canvas.
    xygrid['page'] = labelgrid( disposition )
#    p "xygrid #{xygrid['page']}" 
    # Copy the page label coordinates.
    e = Marshal.load( Marshal.dump( xygrid['page'] ) )
    # Shrink the label icon coordinates.
    e.each { |z| z.collect! { |d| d *= f } }
    # Shrink the icons further to make separations visible.
    e.each { |z| z[2] -= 2.0; z[3] -= 2.0 }
    e.each { |d| d[0] += ::Offset
                 d[2] += ::Offset
                 d[1] += ::Yoff
                 d[3] += ::Yoff
    }
    # Save the label icon coordinates.
    ### new page coordinates
    xygrid['boxes'] = e
    xygrid['max'] = @xymax = nx * ny
    # Clear all the clicked-on flags; whole page available
    reset_flags
    xygrid['page'] = pagegrid( disposition )
    zeta = Marshal.load( Marshal.dump( xygrid['page'] ) )
#    zeta.each { |z| z[2] -= 2.0; z[3] -= 2.0 }
    zeta.each { |b| b[0] += 6
                 b[2] += 6
                 b[1] += 4
                 b[3] += 4
    }
    xygrid['page'] = zeta
   

#    xygrid['page'] = e
#    xygrid['page'].each { |zeta| zeta.collect! { |b| b /= f } }
    xygrid
  end

  # Calculate coordinates for the address labels on the preview screen
  def calcnew ( disposition )
    @nx, @ny = Disposition[disposition]
    @width, @height, @margin, @gap, @bottom = Labelsizes[disposition]
#    @newgrid = Typefaces.labelgrid( disposition )
    @newgrid = labelgrid( disposition )
  end

  # Callback function to update the name list when the category changes
  # It also updates the status on the menubutton bar via the Tk variables
  # @catinfo and @countinfo.
  def newcat ( e )
    win = @env['names']
    @category = e
    @env['category'] = e
    @catinfo.value = e
    win.delete( 0, 'end' )
    @namelist = @paddb.getnames( e )
    @countinfo.value = @namelist.length
    @namelist.each { |r, s| win.insert( 'end', r ) }
  end

  # Specify the printer queue from the printer name.
  def set_queue ( e )
    @printerqueue.value = @device[e.to_sym]
    @printer.value = e
  end

  def savetofile
    outfile = @paddb.filename
    n = @paddb.writefile( outfile )
    puts "#{n} records written"
  end

  # Initialise the label icon canvas for the selected disposition.
  def clearlabels
    grid = @env['newgrid']
    n = grid.length
    (0...n).to_a.each do |i|
      tag = Tag + i.to_s
      @env['clicklist'][i] = 0
      @env['grid'].delete( tag )
    end
    @env['toggle'] = nil
  end

  # Unset all the label icons : the whole page is available
  def clearsheet
    labels = @env['grid']
    grid = @env['newgrid']
    labelsheet = @env['labels']
    i = 0
    clicklist = @env['clicklist']
    grid.each { |box|
      tag = Tag + i.to_s
      labelsheet.delete( tag ) if (labelsheet && clicklist[i] == 2)
#      labels.delete( tag ) unless @env['toggle'] < 0
      labels.delete( tag ) if !@env['toggle']
      icon = TkcRectangle.new( labels, *box ) do
        outline       Clear
        fill          Clear
        tag           tag
      end
      clicklist[i] = 0
      icon.bind( "Button-1", Proc.new{ toggle( tag ) } )
      i += 1
    }
    @env['toggle'] = 0
    @env['set'] = false
    reset_flags
  end

  # Set all the label icons : the whole page is unavailable
  # Useful as a shortcut to unsetting a few icons.
  def fillsheet
    labels = @env['grid']
    grid = @env['newgrid']
    i = 0
    flags = @env['clicklist']
    grid.each { |box|
      if flags[i] == 0 then
        tag = Tag + i.to_s
        labels.delete( tag )
        icon = TkcRectangle.new( labels, *box ) do
          outline       Set
          fill          Set
          tag           tag
        end
        flags[i] = 1
        icon.bind( "Button-1", Proc.new{ toggle( tag ) } )
        i += 1
      end
    }
    @env['toggle'] = 1
    @env['set'] = true
  end

  def drawoutlines
    if ( @env['gridlines'] && !@env['gridset'] ) then
      outlines = @env['page']
      preview = @env['labels']
      outlines.each { |box|
        TkcRectangle.new( preview, *box ) do
          outline       'grey64'
          tag           Ghost
        end
      }
      @env['gridset'] = true
      @env['griddle'].configure( 'foreground' => 'green' )
    end
  end

  # Display the printer page canvas in a separate window.
  def preview ( e, adb )
    clearlabels if @env['oldsheet']
    xygrid = calcxy( e, Scale )
    preview = nil
    w = 595 * Xscale
    h = 842 * Xscale
    @env['disposition'] = e
    if !@env['preview'] then
      preview = TkToplevel.new { title 'Label sheet preview' }
      @env['labels'] = TkCanvas.new( preview ) do
        width       w
        height      h
        background  'azure'
        pack
      end
      @env['preview'] = preview
    end
    @env['newgrid'] = xygrid['boxes']
    @env['page'] = xygrid['page']
    clearsheet
    @env['oldsheet'] = true
    @env['setbutton'].configure( 'text' => 'set' )
    drawoutlines
  end

  # Callback from the set button
  def setorclear
    @env['toggle'] == 1 ? clearsheet : fillsheet
    @env['setbutton'].configure( 'text' => ( @env['set'] ? 'clear' : 'set' ) )
  end

  def findslot
    grid = @env['newgrid']
    flag = @env['clicklist']
    n = grid.length
    i = 0
    box = nil
    while ( i < n ) do
      tag = Tag+i.to_s
      if (flag[i] == 0) then box = grid[i]; break end
      i += 1
    end
    page = @env['page']
    label = page[i] if ( i < n && i >= 0 )
    [ Tag+i.to_s, box, label ]
  end

  def toggle ( tag )
    labels = @env['grid']
    s = tag.delete( Tag ).to_i
#    puts "toggle: tag #{tag} index = #{s}"
    box = @env['newgrid'][s]
    labels.delete( tag )
    if @env['clicklist'][s] == 0 then
#      icon = TkcRectangle.new( labels, box[0], box[1], box[2], box[3] ) do
#      puts "toggle: *box test"
      icon = TkcRectangle.new( labels, *box ) do
        outline       Set
        fill          Set
        tag           tag
      end
      icon.bind( "Button-1", Proc.new { toggle( tag ) } )
      @env['clicklist'][s] = 1
    else
      deletetext( tag ) if @env['clicklist'][s] == 2
      icon = TkcRectangle.new( labels, *box ) do
        outline       Clear
        fill          Clear
        tag           tag
        self.bind( "Button-1") do Proc.new{ toggle( tag ) } end
      end
      @env['clicklist'][s] = 0
    end
  end

  def print
    deletegrid
    @env['gridlines'] = false
    @env['griddle'].configure( 'foreground' => 'LemonChiffon' )
    psfile = "abc-#{@@counter}"
    postscript( @env['labels'], "/tmp/#{psfile}.ps" )
#    puts "print: printerqueue = #{@printerqueue.value}"
    if @printerqueue.value != 'file' then
      command = "lpr -P#{@printerqueue.value} /tmp/#{psfile}.ps"
      system command
    else
      view = "gs /tmp/#{psfile}.ps"
      system view       
    end
    clearsheet
    drawoutlines
    @env['setbutton'].configure( 'text' => 'set' )
    @@counter += 1
  end

  #========================================================================

  def deletegrid
    sheet = @env['labels']
    @config['style'] = 'roman'
    sheet.delete( Ghost )
    @env['gridlines'] = false
    @env['gridset'] = false
    @env['griddle'].configure( 'foreground' => 'LemonChiffon' )
  end

  def deletepage
    sheet = @env['labels']
    i = 0
    @env['clicklist'].each { |k| sheet.delete( Tag+i.to_s ) if k == 2; i += 1 }
    clearsheet
  end

  def deletetext ( tag )
    sheet = @env['labels']
    sheet.delete( tag )
  end

  #========================================================================

  def set_backgroundimage ( sheet, xbyy, origin, yoff, tag )
    labelsizes = Labelsizes[xbyy]
    dx = labelsizes[0].to_f
    dy = labelsizes[1].to_f
    puts "dy = #{dy}"
    offset = yoff - (dy/14.0).floor
    offset = yoff - 11 if ( dy < 61.0 )
    puts "offset = #{offset}"
    j = @env['photocount'] + 1
#    puts "photocount = #{j} #{j.class}"
#    puts "select = #{@env['photoselect']}"
    if @env['new'] then
      photo = @underlay.value
      extension = photo.slice( -3..-1 )
      system "cp #{photo} /tmp/paddb_#{j}.#{extension}"
      photo = "/tmp/paddb_#{j}.#{extension}"
      characteristics = `identify "#{photo}"`
      pieces = characteristics.split
      xx, yy = pieces[2].split( "x" )
      xx = xx.to_i
      yy = yy.to_i
      # The program attempts to fit the image to the given label size.
      if (xx >= 256 || yy >= 256) then
        b = xx > yy ? xx : yy
        factor = (25600.0 / b) - 0.5
        system "mogrify -resize #{factor.floor}% -quality 100 #{photo}"
        characteristics = `identify "#{photo}"`
        pieces = characteristics.split
        xx, yy = pieces[2].split( "x" )
        xx = xx.to_i
        yy = yy.to_i
      end
      percentx = dx / xx
      percenty = dy / yy
      percentx *= 100.0
      percenty *= 100.0
      percentx = percentx.floor
      percenty = percenty.floor
      resize = "#{percentx}%x#{percenty}%"
      system "mogrify -resize #{resize} -quality 100 #{photo}"
      underlay = TkPhotoImage.new( 'file' => photo )
      @env['photolist'][j] = [ @underlay.value, underlay ]
      @photonumber.value = j
      @env['photoselect'] = j
      @env['photocount'] += 1 
      TkcImage.new( sheet, origin+6, offset, 'image' => underlay ) do
        tag  tag
      end
      @env['new'] = @env['blank'] = false
    else
      j = @env['photoselect']
      puts "photoselect = #{j} #{j.class}"
      filename, underlay = @env['photolist'][j]
      @underlay.value = filename
      TkcImage.new( sheet, origin+6, offset, 'image' => underlay ) do
        tag  tag
      end
    end
  end

  def posttext
    if ( sheet = @env['labels'] ) then
      xbyy = @env['disposition']
      slot = findslot
      tag = slot[0]
      box = slot[2]
#      puts "posttext 0: box #{box}"
      text = ""
      n = @scratchpad.length
      u = @config
      typeface = @typeface
      max = 0
      size = @size.value.to_i
      verticaladjustment = size / 12
      verticaladjustment -= size if size > 14 
      
#      puts "posttext 1: vertical #{verticaladjustment}"
      spacing = typeface =~ /Jorvik/
      @scratchpad.each_index do |i|
        text += @scratchpad[i] unless i == n
        text << "\n" if spacing
      end
      @config['size'] = @size.value
      @label[tag] = [ text, Marshal.load( Marshal.dump( @config ) ) ]
      origin = box[0] + @config['margin'] + ::Adjustment[xbyy]
      yoff = box[3] - @config['yoff'] + @registration[xbyy]
      yoff -= verticaladjustment    # 2015-09-11
      u['x0'] = origin
      u['y0'] = yoff
      set_backgroundimage( sheet, xbyy, origin, yoff, tag ) if !@env['blank']
      fontex = @fontex
      TkcText.new( sheet, origin, yoff, 'text' => text ) do
        fill          u['colour']
        font          fontex
        tag           tag
      end
      toggle( tag )
      s = tag.delete( Tag ).to_i
      @env['clicklist'][s] = 2
    end
  end

  def make_odt
    # Creates a temporary text file from the current label text and uses LibreOffice
    # to convert it into an ODT file written to $HOME/Documents/labels/.
    odt = @tempinfo.value.strip
    filename = "/tmp/#{odt}.txt"
    (tempfile = File.new( filename, 'w' )).puts( @labeltext )
    tempfile.close
    command = "libreoffice --headless --convert-to odt --outdir " + @odt
    system( command + " " + filename )
  end

  def modify_label ( text, notes )
    # Popup label editor used for the conversion of label text to ODT format.
    # The notes section may be merged with the address section using 'combine'.
    user = @user
    popup = TkToplevel.new( 'width' => 440, 'height' => 420 )
    popup.geometry( "+200+200" ).title( "Text label editor" )
    popup.background( Panel )
    addr = TkLabel.new( popup ) do
      text               'Address label text'
      pack               'side' => 'top', 'anchor' => 'nw'
    end
    details = TkText.new( popup ) do
      width              44
      height             12
      relief             'raised'
      highlightthickness 0
      pack               'side' => 'top', 'fill' => 'x',
                         'padx' => 2, 'pady' => 2
    end
    details.insert( '1.0', text )
    notez = TkText.new( popup ) do
      width              44
      height             9
      relief             'raised'
      highlightthickness 0
      pack               'side' => 'top', 'fill' => 'x',
                         'padx' => 2, 'pady' => 2
    end
    notez.insert( '1.0', notes )
    details.focus( force = true )
    commands = TkFrame.new( popup ) do
      height             22
      background         Panel
      pack               'side' => 'bottom', 'fill' => 'x'
    end
    # Clicking on Exit invokes the conversion
    # Use window decorations kill button to cancel
    finish = TkButton.new( commands ) do
      text               'Exit'
      command            { user.labeltext = details.value
                           user.make_odt; popup.destroy }
      highlightthickness 0
      pack               'side' => 'right', 'padx' => 2, 'pady' => 4
    end
    tempinfo = user.tempinfo
    aa = TkLabel.new( commands ) do
      text               'rename'
      pack               'side' => 'left', 'padx' => 2
    end
    bb = TkEntry.new( commands ) do
      textvariable       tempinfo
      width              16
      pack               'side' => 'left', 'padx' => 2, 'ipady' => 2
    end
    cc = TkButton.new( commands ) do
      text               'combine'
      command            { details.insert( 'end', '\n'+notez.value ) }
      pack               'side' => 'left', 'padx' => 2, 'ipadx' => 2
    end
    widgets = [ addr, details, notez, finish, aa, bb, cc ]
    widgets.each { |wz| wz.configure( 'background' => ::Panel, 'font' => @font ) }
    [ details, notez, finish, cc ].each { |w| w.configure( 'borderwidth' => 1 ) }
  end

  def make_label
    text = notes = ""
    @scratchpad.each_index { |i| text += @scratchpad[i] }
    @notepad.each_index { |i| notes += @notepad[i] }
    modify_label text, notes
  end

  def fill
    n = @xymax
    0.upto( n-1 ) { |i|
      tag = Tag+i.to_s
      posttext if @env['clicklist'][i] == 0
    }
    @env['setbutton'].configure( 'text' => 'clear' )
    @env['toggle'] = 1
  end

  def save_edit
    p = @env['data']
    i = 0
    @scratchpad.clear
    loop do
      i += 1
      s = i.to_s
      line = p.get( s+'.0', s+'.end' )
      if !line.empty? then
        @scratchpad[i-1] = line + "\n"
      else
        break
      end
    end
    @record['data'] = [ ]
    @scratchpad.each_index { |j| @record['data'][j] = @scratchpad[j] }
    @notepad.clear
    p = @env['notes']
    i = m = 0
    loop do
      i += 1
      s = i.to_s
      line = p.get( s+'.0', s+'.end' )
      if !line.empty? then
        line += "\n"
        @notepad << line
      else
        m = i - 1
        break
      end
    end
    if ( m > 0 ) then
      if !@record['notes'] then
        @record['notes'] = [ ]
      else
        @record['notes'].clear
      end
      @notepad.each_index { |j| @record['notes'][j] = @notepad[j] }
    else
      @record['notes'].clear if @record['notes']
    end
    @env['save'].configure( 'background' => Panel )
    @env['save'].configure( 'foreground' => 'black' )
  end

  def savedatablock ( name, data, pad, iscat )
    # Point to the address section in the main window
    p = @env[name]
    i = 0
    # Clear the transfer buffer
    pad.clear
    # Fill the transfer buffer with successive lines from the input field
    loop do
      i += 1
      line = data.get( "#{i}.0", "#{i}.end" )
      if !line.empty? then
        pad[i-1] = line + "\n"
      else
        break
      end
    end
    if ( iscat ) then
      p.delete( 1.0, 'end' )
      pad.each_index { |j| p.insert( 'end', pad[j] ) }
    end
    i
  end

  # Save the new data from the popup input fields addr and notes
  def save_new ( c, addr, notes )
    iscat = c == @catinfo.value
    # Point to the address section in the main window
    n = savedatablock( 'data', addr, @scratchpad, iscat )
    # Point to the notes section in the main window
    m = savedatablock( 'notes', notes, @notepad, iscat )
    @paddb.newrecord( c, @scratchpad, ( m > 0 ? @notepad : nil ) )
    n = @paddb.records - 1
    if ( c == @env['category'] ) then
      puts "\nSame category"
      j = @countinfo.value.to_i
      @namelist[j] = [ @scratchpad[0].chomp, n ]
      @countinfo.value = (j + 1).to_s
      @env['names'].insert( 'end', @namelist[j][0] )
    else
      puts "insert at #{n}"
    end
  end

  def getfile
    lastdir = @env['home'] + "/images/underlay"
    @underlay.value = Tk::getOpenFile( :initialdir => lastdir  )
    file = @underlay.value.reverse
    i = file.index ( '/' )
    n = file.length
    m = n - i - 1
    lastdir = @underlay.value.slice( 0..m )
    puts "lastdir : #{lastdir}"
    @env['home'] = lastdir
    @env['blank'] = false
    @env['new'] = true 
  end

  # Utility for toggling gridlines on the preview canvas.
  # The lines need to be removed before printing labels.
  def gridlines
    if @env['gridlines'] then
      deletegrid
    else
      @env['gridlines'] = true
      drawoutlines
    end
  end

  # Print the next page in the address book.
  def printpage ( count )
    file = '/tmp/' + "book-#{count}.ps"
    postscript( @env['labels'], file )
    device = @printerqueue.value
    system( "lpr -P#{device} #{file}" ) if device != 'file'
  end

  def deleterecord
    @record['ref'] = -@record['ref']
    if ( @record['ref'] < 0 ) then
      @env['delete'].configure( 'text' => 'undelete' )
    else
      @env['delete'].configure( 'text' => 'delete' )
    end
  end

  def book
    c = @env['labels']
    b = TkcRectangle.new( c, 18, 40, 158, 20 ) do
      fill           'grey22'
      outline        'grey22'
      tag            'ground'
    end
    a = TkcText.new( c, 88, 30, 'text' => "#{@category} : page 1" ) do
        fill           'white'
        tag            'header'
    end
    pagecount = 1
    u = @config
    n = @namelist.length
    s = Disposition[@env['disposition']]
#    d = s[0] < 5 ? 10 : 8
#    z = "{Helvetica Narrow Bold} {#{d}} {normal} {normal}"
#    d = s[0] < 5 ? 10 : 8
#    z = "{URW Gothic L} {9} {normal} {normal}"
    z = "{Blue Highway Condensed} {9} {normal} {normal}"
    typeface = TkFont.new z
    page = @env['page']
    i = k = 0
    m = s[0] * s[1]
    @namelist.each { |name|
      box = page[k]
      origin = box[0] + @config['margin']
      yoff = box[3] - @config['yoff']
      scratchpad = ""
      j = name[1]
      lines = @paddb.record[j]['data']
      lines.each { |s| scratchpad << s }
      z = TkcText.new( c, origin, yoff, 'text' => scratchpad ) do
        fill          u['colour']
        font          typeface
        tag           'leaf'
      end
      i += 1
      if ((( k += 1 ) == m) || i == n ) then
        printpage( pagecount )
        if ( i == n ) then break end
        c.delete( 'header' )
        c.delete( 'leaf' )
        pagecount += 1
        a = TkcText.new( c, 88, 30,
                         'text' => "#{@category} : page #{pagecount}" ) do
          fill           'white'
          tag            'header'
        end
        k = 0
      end
    }

  end

  #========================================================================

  def newtext ( w, z )
    @scratchpad.each { |line| w.insert( 'end', line ) }
    @notepad.each { |line| z.insert( 'end', line ) }
  end

  def addentry
    user = @user
    popup = TkToplevel.new( 'width' => 460, 'height' => 450 )
    popup.geometry( "+200+200" ).title( "Address editor" )
    popup.background( Panel )
    @tempinfo.value = @env['category']
    text = @env['editmode'] == 'new' ? 'Enter new address' : 'Edit address'

    TkLabel.new( popup ) do
      text               text
      font               user.font
      background         Panel
      pack               'side' => 'top', 'anchor' => 'nw'
    end

    d = TkText.new( popup ) do
      width              64
      height             16
      background         Panel
      relief             'raised'
      borderwidth        1
      highlightthickness 0
      font               user.font
      pack               'side' => 'top', 'fill' => 'x',
                         'padx' => 2, 'pady' => 6
    end

    text = @env['editmode'] == 'new' ? 'Optional information' : 'Edit notes'

    TkLabel.new( popup ) do
      text               text
      font               user.font
      background         Panel
      pack               'side' => 'top', 'anchor' => 'nw'
    end

    n = TkText.new( popup ) do
      width              64
      height             16
      background         Panel
      relief             'raised'
      borderwidth        1
      highlightthickness 0
      font               user.font
      pack               'side' => 'top', 'fill' => 'x',
                         'padx' => 2, 'pady' => 6
    end

    if ( @env['editmode'] == 'clone' ) then newtext( d, n ) end
    d.focus( force = true )

    n.bind( "ButtonPress-3" ) do
      @notepad.clear
      n.delete( 1.0, 'end' )
    end

    commands = TkFrame.new( popup ) do
      height             22
      background         Panel
      pack               'side' => 'bottom', 'fill' => 'x'
    end

    tempinfo = @tempinfo
    finish = TkButton.new( commands ) do
      text               'Exit'
      font               user.font
      background         Panel
      command            { user.save_new( tempinfo.value, d, n ); popup.destroy }
      border             1
      highlightthickness 0
      pack               'side' => 'right', 'pady' => 4
    end

    TkLabel.new( commands ) do
      text               'category'
      font               user.font
      background         Panel
      pack               'side' => 'left', 'padx' => 2
    end

    cc = TkEntry.new( commands ) do
      textvariable       tempinfo
      font               user.font
      background         Panel
      width              16
      border             1
      pack               'side' => 'left', 'padx' => 4, 'ipadx' => 2
    end

  end

  #========================================================================

  def findtext ( record, text )
    found = false
    record['data'].each { |line|
      buffer = line.downcase
      if ( found = buffer.index( text ) ) then break end
    }
    if ( !found && record['notes'] ) then
      record['notes'].each { |line|
        buffer = line.downcase
        if ( found = buffer.index( text ) ) then break end
      }
    end
    found
  end

  def findall ( text, data, notes, cat )
    k = 0
    p = @paddb.record
    @paddb.categories.each do |c|
      @paddb.category_index[c].each do |a|
        j = a[1]
        if findtext( p[j], text ) then @result[k] = j; k += 1 end
      end
    end
    k
  end

  def showit ( p, data, notes )
    # Clear the data displays
    data.delete( 1.0, 'end' )
    notes.delete( 1.0, 'end' )
    @scratchpad.clear
    @notepad.clear
    # Copy data for the selected record to the display
    lines = p['data']
    lines.each { |s| data.insert( 'end', s ); @scratchpad << s }
    lines = p['notes']
    lines.each { |s| notes.insert( 'end', s ); @notepad << s } if lines
  end

  def shownext ( data, notes, cat )
    return if @rec == @results
    p = @paddb.record[@result[@rec]]
    category = p['category']
    showit( p, data, notes )
    cat.configure( 'text' => "category = #{category}" )
    @rec += 1
  end

  def displayresult
    @rec -= 1
    j = @result[@rec]
    @record = @paddb.record[j]
    newcat( @record['category'] )
    data = @env['data']
    notes = @env['notes']
    showit( @record, data, notes )
    @dateinfo.value = @paddb.record[j]['date'].chomp
    # State changes
    if ( @record['ref'] >= 0 ) then
      @env['delete'].configure( 'text' => 'delete' )
      @changes = true
    else
      @env['delete'].configure( 'text' => 'undelete' )
    end
    @env['save'].configure( 'background' => Panel )
    @env['save'].configure( 'foreground' => 'black' )

    data.bind( "KeyPress" ) do
      @env['save'].configure( 'background' => 'grey61' )
      @env['save'].configure( 'foreground' => 'green' )
    end

  end

  def findstring
    searcher = TkToplevel.new( 'width' => 460, 'height' => 450 )
    searcher.geometry( "+200+200" ).title( "Search results" )
    searcher.background( Panel )

    text = @searchstring.value.strip.downcase
    @tempinfo.value = " "
    @result.clear
    @rec = 0
    user = @user

    reminder = TkFrame.new( searcher ) do
#      background         Panel
      background         'CadetBlue'
      pack               'side' => 'top', 'fill' => 'x'
    end

    srchl = TkLabel.new( reminder ) do
      text               'Search for : '
      font               user.font
      background         Panel
#      width              13
      pack               'side' => 'left', 'padx' => 4, 'ipadx' => 2
    end

    srchs = TkLabel.new( reminder ) do
      text               text
      font               user.font
      background         Panel
      foreground         'Blue'
#      width              28
      pack               'side' => 'left', 'padx' => 4, 'ipadx' => 2
    end

    d = TkText.new( searcher ) do
#      width              64
      height             16
      background         Panel
      relief             'raised'
      borderwidth        1
      highlightthickness 0
      font               user.font
      pack               'side' => 'top', 'fill' => 'x',
                         'padx' => 2, 'pady' => 6
    end

    n = TkText.new( searcher ) do
      width              64
      height             16
      background         Panel
      relief             'raised'
      borderwidth        1
      highlightthickness 0
      font               user.font
      pack               'side' => 'top', 'fill' => 'x',
                         'padx' => 2, 'pady' => 6
    end

    commands = TkFrame.new( searcher ) do
      height             22
      background         Panel
      pack               'side' => 'bottom', 'fill' => 'x'
    end

    finish = TkButton.new( commands ) do
      text               'exit'
      font               user.font
      background         Panel
      command            { searcher.destroy }
      border             1
      highlightthickness 0
      pack               'side' => 'right', 'pady' => 4, 'padx' => 4,
                         'ipadx' => 2
    end

    ok = TkButton.new( commands ) do
      text               'accept'
      font               user.font
      background         Panel
      command            { user.displayresult }
      border             1
      highlightthickness 0
      pack               'side' => 'right', 'padx' => 4, 'ipadx' => 2
    end

    cc = TkLabel.new( commands ) do
      text               'category =        '
      font               user.font
      background         Panel
#      width              20
      pack               'side' => 'left', 'padx' => 4, 'ipadx' => 2
    end

    r = TkLabel.new( commands ) do
      text               '@'
      font               user.font
      background         Panel
#      width              22
      pack               'side' => 'left', 'padx' => 4, 'ipadx' => 2
    end

    nextresult = TkButton.new( commands ) do
      text               'next'
      font               user.font
      background         Panel
      width              8
      border             1
      highlightthickness 0
      command            { user.shownext( d, n, cc ) }
      pack               'side' => 'right', 'padx' => 4, 'ipadx' => 2
    end

    @results = findall( text, d, n, cc )
    if ( @results == 0 ) then
      r.configure( 'text' => "String not found" )
    else
      match = @results > 1 ? 'matches' : 'match'
      r.configure( 'text' => "#{@results} #{match} found" )
      shownext( d, n, cc )
    end
  end

  def samplefont ( e )
    z = "{#{e}} {11} {normal} {normal}"
    font = TkFont.new z 
    @example.value = e + " #{@size.value}"
    user.env['fontview'].configure( 'font' => font ) 
  end

  def select_image ( obj, images )
    xzx = TkToplevel.new( )
    xzx.geometry( "+200-400" ).title( "Select background underlay" )
    xzx.background( ::Panel )
    imx = TkListbox.new( xzx ) do
      height      24
      width       38
      background  ::Panel
      font        ::Larabie
      pack        'side' => 'top'
      images.each { |z| self.insert( 'end', z ) }
      self.bind( "ButtonRelease-1" ) {
        name = self.get( *imx.curselection )
        obj.underlay.value = name
        obj.env['photocount'] += 1
        j = obj.env['photocount']
        obj.env['photonumber'] = j
        obj.env['new'] = true
        obj.env['blank'] = false
      }
    end
  end

  def show_background ( obj )
    images = `ls /tmp/paddb_x*.*`.split( "\n" )
    select_image( obj, images )
  end

  def generate_background ( obj )
    system "/home/lcl/bin/newpatterns"
  end
 
  def page_interface ( user, sub, oko, typeface )

    zig = TkFrame.new( oko ) do
#      width              150
      height             100
      pack               'side' => 'left', 'fill' => 'x', 'expand' => true
    end

    device = TkEntry.new( zig ) do
      textvariable       user.printer
      width              18
      relief             'flat'
      foreground         'MidnightBlue'
      pack               'side' => 'top', 'pady' => 14
    end

    user.env['fontview'] = example = TkEntry.new( zig ) do
      textvariable       user.example
      width              26
      border             1
      highlightthickness 0
      foreground         'black'
      pack               'side' => 'top', 'pady' => 14, 'ipady' => 4#,
#                         'expand' => true
    end

    beware = "Be aware that not all printed
fonts have style options like
bold and italic."

    warning = TkLabel.new( zig ) do
      text               beware
      font               ::Small
      foreground         'grey41'
      highlightthickness 0
      pack               'side' => 'top'
    end

    italic = TkCheckbutton.new( zig ) do
      text               'italic'
      variable           user.italic
      indicatoron        false
      selectcolor        'LemonChiffon'
      offrelief          'flat'
      overrelief         'raised'
      border             1
      command            proc { user.updatelabelstyle } 
      pack               'side' => 'top', 'pady' => 14
    end

    bold = TkCheckbutton.new( zig ) do
      text               ' bold '
      variable           user.bold
      indicatoron        false
      selectcolor        'LemonChiffon'
      offrelief          'flat'
      overrelief         'raised'
      border             1
      command            proc { user.updatelabelstyle }
      pack               'side' => 'top', 'pady' => 14
    end
=begin
    zag = TkFrame.new( oko ) do
      height             230
      relief             'groove'
      borderwidth        2
      pack               'side' => 'right', 'pady' => 3,
                         'fill' => 'x', 'expand' => true
    end
=end
    grid = TkCanvas.new( oko ) do
      width              200
      height             230
      relief             'groove'
      borderwidth        2
#      pack               'side' => 'right', 'padx' => 4, 'pady' => 8
      pack               'side' => 'right', 'pady' => 3,
                         'fill' => 'x', 'expand' => true
    end

    user.env['grid'] = grid
    printer = TkMenuButton.new( sub ) do
      text         'printer'
      menu TkMenu.new( self ) {
        tearoff   false
        user.device.each_key { |e| add 'command',
          { 'label' => e, 'font' => typeface,
            'command' => proc { user.set_queue( e ) } }
        }
      }
      relief             'flat'
      pack               'side' => 'left'
    end

    sheet = TkMenuButton.new( sub ) do
      text               'sheet'
      menu TkMenu.new( self ) {
        tearoff   false
        Disposition.each_key { |e| add 'command',
          { 'label' => e, 'font' => typeface,
            'command' => proc { user.preview( e, user.paddb ) } }
        }
      }
      relief             'flat'
      pack               'side' => 'left'
    end

    fontmenu( user, sub )
    size = user.size

    sz = TkEntry.new( sub ) do
      textvariable       size              
      width              3
      pack               'side' => 'left', 'padx' => 6
      self.bind ( "Return" ) { user.setlabelsize }
    end

    colour = TkMenuButton.new( sub ) do
      text               'colour'
      menu TkMenu.new( self ) {
        tearoff   false
        user.env['colours'].each_key { |e| add 'command',
          { 'label' => e, 'font' => typeface,
            'command' => proc { user.setlabelcolour( user.env['colours'][e] ) } }
        } 
      }
      relief             'flat'
      pack               'side' => 'left'
    end

    user.env['setbutton'] = set = TkButton.new( sub ) do
      text               'set'
      relief             'flat'
      command            { user.setorclear }
      pack               'side' => 'left'
    end

    user.env['griddle'] = griddle = TkButton.new( sub ) do
      text               'gridlines'
      relief             'flat'
      command            { user.gridlines }
      pack               'side' => 'right'
    end

    wwt = [ device, italic, bold ]
#    wbg = [ zig, zag, grid, example ]
    wbg = [ zig, grid, example ]
    wbg.concat( wwt ).flatten!
    wwt.each { |w| w.configure( 'font' => user.font ) }
#    wbg.each { |w| w.configure( 'background' => 'LemonChiffon' ) }
    wbg.each { |w| w.configure( 'background' => 'grey88' ) }
    wbg.each { |w| w.configure( 'highlightthickness' => 0 ) }
    pb = [ printer, sheet, sz, colour, set, griddle ]
    pb.each { |w| w.configure( 'foreground' => 'LemonChiffon',
                               'background' => 'grey36',
                               'font' => user.font,
                               'highlightthickness' => 0 ) }
  end

  def build_interface ( user )

    root = TkRoot.new { title Version }
    root.geometry( "+400+20" )

    top = TkFrame.new( root ) do
      height             320
      background         'pink'
      pack
    end

    # Set up top button and menubar

    buttons = TkFrame.new( top ) do
      height             22
      border             2
      background         'orange'
      pack               'side' => 'top', 'fill' => 'x', 'expand' => true
    end

    typeface = user.font

    items = [ ]
    user.paddb.categories.each { |c| items << c }
#    @category = @paddb.default_category
    user.category = " "
    user.catinfo.value = user.category

    user.config['font'] = 'Andale Mono'
    puts "default display font = #{user.config['font']}"
    user.device = { }
    user.paddb.printers.each { |c| user.device[c[0]] = c[1] if c[0] != 'default' }

    #------------------------------------------------

    frame = TkFrame.new( root ) do
#      width              840
      height             300
      background         'thistle'
      pack               'side' => 'top'
    end

    photos = TkFrame.new( root ) do
      height             22
      border             0
      pack               'side' => 'top', 'fill' => 'x', 'expand' => true
    end

    generator = TkFrame.new( root ) do
      height             22
      border             0
      pack               'side' => 'top', 'fill' => 'x', 'expand' => true
    end

    face = TkFont.new "{Larabiefont} {11} {normal} {normal}"

    getpic = TkButton.new( photos ) do
      text               'getfile'
      font               face
      highlightthickness 0
      border             0
      command            { Thread.new { user.getfile } }
      pack               'side' => 'left', 'padx' => 2      
    end

    bim = TkLabel.new( photos ) do
      text               "Photo underlay"
      font               face
      pack               'side' => 'left', 'padx' => 2
    end
 
    bimage = TkEntry.new( photos ) do
      textvariable       user.underlay
      width              50
      font               face
      highlightthickness 0
      background         'grey88'
      pack               'side' => 'left', 'fill' => 'x', 'pady' => 4      
      self.bind( "Button-3" ) { user.underlay.value = "" }
      self.bind( "Return" ) { user.photonumber.value = "" }
    end

#    photonumber = user.env['photocount'].to_s
#    puts "photo number = #{photonumber}"

    photon = TkEntry.new( photos ) do
      textvariable       user.photonumber
      width              3
      font               face
      background         'grey88'
      pack               'side' => 'left', 'padx' => 4
    end

    gen = TkButton.new( generator ) do
      text               "Generate new backgrounds"
      font               face
      command            { user.generate_background }
      pack               'side' => 'left', 'pady' => 4, 'fill' => 'x'
    end

    oldimage = TkEntry.new( generator ) do
      textvariable       user.photo
      width              4
      font               face
      highlightthickness 0
      background         'grey88'
      pack               'side' => 'left', 'fill' => 'x',
                         'padx' => 4, 'pady' => 4      
      self.bind( "Return" ) { user.env['photoselect'] = self.value.to_i }
      self.bind( "Button-3" ) { user.env['photoselect'] = nil
                                self.value = "" }
    end

    backview = TkButton.new( generator ) do
      text               "Select background image"
      font               face
      command            { user.show_background user }
      pack               'side' => 'right', 'pady' => 4, 'fill' => 'x'
    end

    cancel = TkButton.new( generator ) do
      text               "off"
      background         ::Panel
      font               face
      relief             'flat'
      command            { user.env['blank'] = true }
      pack               'side' => 'right', 'pady' => 2
    end

    stats = TkFrame.new( root ) do
#      width              840
      height             48
      relief             'groove'
      background         'azure'
      border             2
      pack               'side' => 'top', 'fill' => 'x'
    end

    left = TkFrame.new( frame ) do
#      width              400
      height             240
      background         Panel
      pack               'side' => 'left'
    end

    user.env['names'] = names = TkListbox.new( left ) do
      width              42
      height             35
      pack               'side' => 'left', 'fill' => 'both'
    end

    user.wwt << names
    user.names = names

    # Set up the scrollbar.
    scroller = TkScrollbar.new( left ) do
      border             1
      command            { |*args| names.yview *args }
      pack               'side' => 'left', 'fill' => 'y'
    end

    names.yscrollcommand { |first,last| scroller.set( first, last ) }
#    dab = user.paddb

    right = TkFrame.new( frame ) do
      width              300
      height             240
      pack               'side' => 'right', 'expand' => true
    end

    user.wbg << stats << frame << left << names << scroller

    user.env['data'] = data = TkText.new( right ) do
      width              34
      height             10
      relief             'flat'
      pack               'side' => 'top', 'fill' => 'x', 'expand' => false,
                         'ipadx' => 1, 'padx' => 1
    end

    data.bind( "KeyPress" ) do
      user.env['save'].configure( 'background' => 'grey61' )
      user.env['save'].configure( 'foreground' => 'green' )
    end

    user.env['notes'] = notes = TkText.new( right ) do
      width              34
      height             8
      relief             'flat'
      pack               'side' => 'top', 'pady' => 7, 'ipadx' => 1,
                         'padx' => 1, 'fill' => 'x', 'expand' => false
    end

    notes.bind( "KeyPress" ) do
      user.env['save'].configure( 'background' => 'grey61' )
      user.env['save'].configure( 'foreground' => 'green' )
    end

    # When an entry is selected from the name list write the relevant
    # address and notes lines to the data and notes text displays.
    names.bind( "ButtonRelease-1" ) do
      user.record = nil
      # Retrieve name from selected item in listbox
      namekey = names.get( *names.curselection )
      i = names.curselection[0]
      j = -1
      j = user.namelist[i][1] if user.namelist[i][0] == namekey
      user.record = user.paddb.record[j] if j > -1
      # Clear the data displays
      data.delete( 1.0, 'end' )
      notes.delete( 1.0, 'end' )
      user.scratchpad.clear
      user.notepad.clear
      # Copy data for the selected record to the display
      lines = user.paddb.record[j]['data']
      lines.each { |s| data.insert( 'end', s ); user.scratchpad << s }
      lines = user.paddb.record[j]['notes']
      lines.each { |s| notes.insert( 'end', s ); user.notepad << s } if lines
      @dateinfo.value = @paddb.record[j]['date'].chomp
      @type.value = @paddb.record[j]['category']
      # State changes
      if ( user.record['ref'] >= 0 ) then
        user.env['delete'].configure( 'text' => 'delete' )
        user.changes = true
      else
        user.env['delete'].configure( 'text' => 'undelete' )
      end
      user.env['save'].configure( 'background' => Panel )
      user.env['save'].configure( 'foreground' => 'black' )
      data.bind( "KeyPress" ) do
        user.env['save'].configure( 'background' => 'grey61' )
        user.env['save'].configure( 'foreground' => 'green' )
        user.changes = true
      end
    end

    cat = TkMenubutton.new( buttons ) do
      text        'group'
      menu TkMenu.new( self ) {
        tearoff   false
        items.each { |e| add 'command',
          { 'label' => e, 'font' => typeface,
            'command' => Proc.new { user.newcat( e ) } }
        }
      }
      relief      'flat'
      background  'grey77'
      pack        'side' => 'left' #, 'padx' => 8
      self.bind( "Button-2" ) { $info = user.showinfo( user.help['cat'] ) }
      self.bind( "Leave" ) { $info.destroy if $info }
    end
=begin
    TkLabel.new( buttons ) do
      text               ' '
      background         'grey88'
      pack               'side' => 'left'
    end
=end
    info = TkEntry.new( stats ) do
      textvariable  user.catinfo
      foreground    'LemonChiffon'
      width         14
      relief        'flat'
      pack          'side' => 'left', 'pady' => 4, 'padx' => 1
    end

    entries = TkEntry.new( stats ) do
      textvariable  user.countinfo
      foreground    'LemonChiffon'
      width         5
      relief        'flat'
      pack          'side' => 'left', 'pady' => 4, 'padx' => 1
    end

    prompt = TkLabel.new( stats ) do
      text          'Search string'
      foreground    'grey18'
      width         13
      pack          'side' => 'left'
    end

    search = TkEntry.new( stats ) do
      textvariable  user.searchstring
      foreground    'grey18'
      width         24
      border        1
      pack          'side' => 'left', 'padx' => 1, 'pady' => 5, 'ipadx' => 2
    end

    search.bind( "ButtonPress-3" ) do user.searchstring.value = "" end
    search.bind( "Return" ) do user.findstring end

    added = TkEntry.new( stats ) do
      textvariable  user.dateinfo
      foreground    'grey18'
      width         16
      relief        'flat'
      pack          'side' => 'right', 'padx' => 1, 'pady' => 5, 'ipadx' => 2
    end

    quit = TkButton.new( buttons ) do
      text               'exit'
      command            { closedown( user ) }
      relief             'flat'
      pack               'side' => 'right' #, 'ipadx' => 6
    end
=begin
    TkLabel.new( buttons ) do
      text               ' '
      background         'grey88'
      pack               'side' => 'right'
    end
=end
    wwt << cat << info << entries << quit << prompt << search
    wbg << root << top << buttons << cat << info << entries << quit
    wbg << prompt << search

    new = TkButton.new( buttons ) do
      text               'new'
      command            { user.env['editmode'] = 'new'; user.addentry }
      relief             'flat'
      pack               'side' => 'left' #, 'padx' => 8
      self.bind( "Button-2" ) { $info = user.showinfo( user.help['new'] ) }
      self.bind( "Leave" ) { $info.destroy if $info }
    end

    clone = TkButton.new( buttons ) do
      text               'clone'
      command            { user.env['editmode'] = 'clone'; user.addentry }
      relief             'flat'
      pack               'side' => 'left' #, 'padx' => 8
      self.bind( "Button-2" ) { $info = user.showinfo( user.help['clone'] ) }
      self.bind( "Leave" ) { $info.destroy if $info }
    end

    print = TkButton.new( buttons ) do
      text               'print'
      command            { user.print }
      relief             'flat'
      pack               'side' => 'right' #, 'padx' => 6
      self.bind( "Button-2" ) { $info = user.showinfo( user.help['print'] ) }
      self.bind( "Leave" ) { $info.destroy if $info }
    end

    repeat = TkButton.new( buttons ) do
      text               'fill'
      command            { user.fill }
      relief             'flat'
      pack               'side' => 'right' #, 'padx' => 6
      self.bind( "Button-2" ) { $info = user.showinfo( user.help['fill'] ) }
      self.bind( "Leave" ) { $info.destroy if $info }
    end

    add = TkButton.new( buttons ) do
      text               'add'
      command            { user.posttext }
      relief             'flat'
      pack               'side' => 'right', 'ipady' => 1 #, 'padx' => 6
      self.bind( "Button-2" ) { $info = user.showinfo( user.help['add'] ) }
      self.bind( "Leave" ) { $info.destroy if $info }
    end

    wp = TkButton.new( buttons ) do
      text               'odt'
      command            { user.make_label }
      relief             'flat'
      pack               'side' => 'right', 'ipady' => 1 #, 'padx' => 6
      self.bind( "Button-2" ) { $info = user.showinfo( user.help['odt'] ) }
      self.bind( "Leave" ) { $info.destroy if $info }
    end

    user.env['delete'] = delete = TkButton.new( buttons ) do
      text               'delete'
      command            { user.deleterecord }
      relief             'flat'
      pack               'side' => 'left' #, 'padx' => 3
      self.bind( "Button-2" ) { $info = user.showinfo( user.help['del'] ) }
      self.bind( "Leave" ) { $info.destroy if $info }
    end

    user.env['edcat'] = change = TkEntry.new( buttons ) do
      textvariable       user.type
      width              10
      border             1
      pack               'side' => 'left' #, 'padx' => 3
      self.bind( "Button-2" ) { $info = user.showinfo( user.help['edcat'] ) }
      self.bind( "Leave" ) { $info.destroy if $info }
    end

    change.bind( "Return" ) {
       newcategory = user.type.value
       user.paddb.edit_cat( user.record, newcategory )   
    }

    user.env['save'] = save = TkButton.new( buttons ) do
      text               'save edit'
      relief             'flat'
      command            { user.save_edit }
      pack               'side' => 'left' #, 'padx' => 3
      self.bind( "Button-2" ) { $info = user.showinfo( user.help['save'] ) }
      self.bind( "Leave" ) { $info.destroy if $info }
    end

    book = TkButton.new( buttons ) do
      text               'book'
      relief             'flat'
      command            { user.book }
      pack               'side' => 'left' #, 'padx' => 5
      self.bind( "Button-2" ) { $info = user.showinfo( user.help['book'] ) }
      self.bind( "Leave" ) { $info.destroy if $info }
    end

    wwt << print << new << save << clone << change << add << delete << book
    wbg << print << new << save << clone << change << add << delete << book

    wwt << repeat << data << notes << added << wp
    wbg << repeat << data << notes << added << wp

    sub = TkFrame.new( right ) do
#      width              360
      height             20
      background         'LightSteelBlue'
      pack               'side' => 'top', 'fill' => 'x', 'expand' => true
    end

    oko = TkFrame.new( right ) do
#      width              360
      height             100
      background         'OliveDrab'
      pack               'side' => 'top', 'fill' => 'x', 'expand' => true
    end

    page_interface( user, sub, oko, typeface )

    wbg << sub << oko
    # Configure general properties and specific ones
    wwt.each { |w| w.configure( 'font' => user.font ) }
    wbg.each { |w| w.configure( 'background' => 'grey88' ) }
    data.configure( 'background' => 'grey94' )
    notes.configure( 'background' => 'grey94' )
    wbg.each { |w| w.configure( 'highlightthickness' => 0 ) }
    [ info, entries, sub ].each { |w| w.configure( 'background' => 'grey36' ) }

  end

  def showinfo ( message )
    $info = nil
    buffer = message.split( "\n" )
    lines = buffer.length
    max = 0
    buffer.each { |line| if (n = line.length) > max then max = n end }
    max *= 9
    lines *= 20; lines += 10
    help = TkToplevel.new( ).geometry( "#{max}x#{lines}+300+200" )
    Tk::Wm.overrideredirect( help, true )
    typeface = TkFont.new "{Larabiefont} {10} {normal} {normal}"
    bubble = TkText.new( help ) do
#      width       22
#      height      4
      font        typeface
      background  'LemonChiffon'
      pack        'side' => 'top', 'expand' => true
    end
    bubble.insert( 'end', message )
    help
  end

  def initialize ( paddb )

    @paddb = paddb
    @font = paddb.default_font
    title = "paddb " + Version
    @wwt = [ ]
    @wbg = [ ]
    @device = { }
    @maxrec = paddb.records

    @namelist   = [ ]
    @scratchpad = [ ]
    @notepad    = [ ]
    @fontmap    = { }
    @label      = { }
    @result     = [ ]
    @rec        = 0
    @results    = 0
    @changes    = true
    @xymax      = 0
    @user       = self
    @typeface   = nil
    @fontex     = TkFont.new "{Courier} {11} {normal} {normal}"
    @printerdefault = paddb.default_printer
    defaultqueue  = paddb.printers[@printerdefault.to_sym]
    @catinfo      = TkVariable.new( ' ' )
    @countinfo    = TkVariable.new( 0 )
    @colour       = TkVariable.new( 'black' )
    @dateinfo     = TkVariable.new( ' ' )
    @example      = TkVariable.new( ' ' )
    @size         = TkVariable.new( 13 )
    @printerqueue = TkVariable.new( defaultqueue )
    @printer      = TkVariable.new( @printerdefault )
    @italic       = TkVariable.new( 0 )
    @bold         = TkVariable.new( 0 )
    @searchstring = TkVariable.new( ' ' )
    @tempinfo     = TkVariable.new( ' ' )
    @labeltext    = TkVariable.new( "" )
    @type         = TkVariable.new( "" )
    @photo        = TkVariable.new( "" )
    @photonumber  = TkVariable.new( "" )
    @underlay     = TkVariable.new( "" )
    @help         = { 'cat'   => "address category",
                      'new'   => "Create new entry",
                      'clone' => "Edit clone of
current entry",
                      'del'   => "Delete current entry.
Recover this entry",
                      'edcat' => "Change the current category
or name a new category for
the current entry.",
                      'save'  => "Record this entry or
all changes will be lost",
                      'book'  => "Print address book for
current category.
Select label type beforehand.",
                      'add'   => "Post this entry
on the labelsheet",
                      'odt'   => "Generate an odt
label file",
                      'fill'  => "Fill the whole sheet
with current entry",
                      'print' => "Print labelsheet as is"                     
                    }

    @odt = @paddb.odt              
    colourlist = @paddb.colours
    colours = { }
    colourlist.each { |k, rgb| colours[k] = rgb == "nil" ? k : rgb }

    @env                = ::Env
    @env['category']    = @default_category
    @env['Xfont']       = @default_font
    @env['displayfont'] = @default_font
    @env['colours']     = colours
    @config             = ::Config
    @config['xfont']    = @env['Xfont']
    @registration       = ::Registration

    build_interface self
    set_queue @printerdefault
  end

end

# Initialize the database and build the gui

addresses, namelist = Address.new( nil )
display = User.new( addresses )
Tk.mainloop
