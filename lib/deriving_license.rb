require "gemnasium/parser"
require "bundler"
require "safe_yaml"

class DerivingLicense
  
  attr_reader :license_details, :license_aliases
  
  # TODO: Scrape http://www.gnu.org/licenses/license-list.html#SoftwareLicenses 
  # and auto-magically generate these details.
  @@license_details = {
    # key -> hash of (Name, Link, [Tags]), where tags is an array that may include [:gpl_compatible, :copyleft_compatible, :has_restrictions]
    "GPL" => {name:"GNU General Public License",link:"http://en.wikipedia.org/wiki/GNU_General_Public_License",tags:[:gpl_compatible, :copyleft_compatible, :has_restrictions]},
    "MIT" => {name:"Expat License",link:"http://directory.fsf.org/wiki/License:Expat",tags:[:gpl_compatible, :has_restrictions]},
    "BSD" => {name:"FreeBSD Copyright",link:"http://www.freebsd.org/copyright/freebsd-license.html",tags:[:gpl_compatible, :copyleft_compatible, :has_restrictions]}
  }

  @@license_aliases = {
    # hash of names to keys of the license in the master list.
    "FreeBSD" => "BSD",
    "Expat" => "MIT"
  }

  def self.run(path=nil)
    unless path
      raise ArgumentError.new("Path to Gemfile or Gemspec required")
    end
    
    unless /(gemfile|gemspec)+/.match(path.downcase)
      raise ArgumentError.new("Argument must be a path to Gemfile or Gemspec")
    end
    
    begin
      content = File.open(path, "r").read
    rescue
      raise "Invalid path to gemfile or gemspec."
    end
    
    gemfile = Gemnasium::Parser::Gemfile.new(content)
    
    licenses = Hash.new(0)
    gemfile.dependencies.each do |d|
      # See if it's installed locally, and if not add -r to call
      Bundler.with_clean_env do # This gets out of the bundler context.
        remote = /#{d.name}/.match( `BUNDLE_GEMFILE=#{path}; gem list #{d.name}` ) ? "" : "-r "      
        print "Determining license for #{d.name}#{remote.empty? ? "" : " (remote call required)"}..."
        yaml = `gem specification #{remote}#{d.name} --yaml`
        @spec = YAML.load(yaml, :safe => true)
      end
      print "#{@spec["licenses"].empty? ? "UNKNOWN" : "SUCCESS"}\n"
      @spec["licenses"].each{ |l| licenses[l]+=1 }
    end
    licenses
  end
  
  def self.describe(licenses)
    # Print link to description of each license type, then attempt to determine 
    # whether any notable restrictions apply (e.g. you can't sell this project, 
    # you must include a copy of the GPL, etc)
    unknowns = []
    output = []
    licenses.each do |l|
      instances = "(#{l.last} instance#{l.last == 1 ? "" : "s"})"
      key = @@license_aliases[l.first]
      key ||= l.first
      if @@license_details[key]
        output << "#{key}: #{@@license_details[key][:name]} #{instances}[#{@@license_details[key][:link]}]"
      else
        unknowns << key
      end
    end
    unless output.empty?
      puts "Detected #{output.count} known license#{output.count==1 ? "" : "s"}:"
      output.each{|o| puts o}
    end
    unless unknowns.empty?
      puts "There #{unknowns.count==1 ? "is" : "are"} also #{unknowns.count} unknown license#{unknowns.count==1 ? "" : "s"}: #{unknowns.join(', ')}"
    end
  end
end