require 'fileutils'

module TogoID

  class Ontology
    def initialize(tio_nt)
      @category_color = CategoryColor.new
      @pred_rdfs_label = {}
      @pred_disp_label = {}
      tio_nt.each_line do |line|
        s, p, o = line.split(/\s+/, 3)
        pred = s.scan(/TIO_\d+/).first
        label = o.scan(/"(.*)"/).first

        # <http://togoid.dbcls.jp/ontology#TIO_000014> <http://www.w3.org/2000/01/rdf-schema#label> "structure has protein domain" .
        if line[/ontology#TIO_/] and line[/rdf-schema#label/] and label
          @pred_rdfs_label[pred] = label.first
        end

        # <http://togoid.dbcls.jp/ontology#TIO_000014> <http://togoid.dbcls.jp/ontology#display_label> "has protein domain" .
        if line[/ontology#TIO_/] and line[/ontology#display_label/] and label
          @pred_disp_label[pred] = label.first
        end
      end
    end

    def predicate(pred)
      "tio:#{pred}"
    end

    def rdfs_label(pred)
      @pred_rdfs_label[pred] || predicate(pred)
    end

    def disp_label(pred)
      @pred_disp_label[pred] || predicate(pred)
    end

    def color(category)
      @category_color[category]
    end

    class CategoryColor
      PALETTE = {
        "Analysis"	=> "#696969",
        "Compound"	=> "#A853C6",
        "Disease"	=> "#5361C6",
        "Domain"	=> "#A2C653",
        "Experiment"	=> "#696969",
        "Function"	=> "#696969",
        "Gene"		=> "#53C666",
        "Glycan"	=> "#673AA6",
        "Interaction"	=> "#C65381",
        "Literature"	=> "#696969",
        "Ortholog"	=> "#53C666",
        "Pathway"	=> "#C65381",
        "Probe"		=> "#53C666",
        "Project"	=> "#696969",
        "Protein"	=> "#A2C653",
        "Reaction"	=> "#C65381",
        "Sample"	=> "#696969",
        "SequenceRun"	=> "#696969",
        "Structure"	=> "#C68753",
        "Submission"	=> "#696969",
        "Taxonomy"	=> "#006400",
        "Transcript"	=> "#53C666",
        "Variant"	=> "#53C3C6",
      }

      def initialize
        PALETTE.default = "#333333"
      end

      def [](category)
        PALETTE[category]
      end
    end
  end

  # Dataset
  class Node
    attr_reader :catalog, :category, :label, :prefix, :regex, :internal_format, :external_format
    def initialize(hash)
      @catalog = hash["catalog"]
      @category = hash["category"]
      @label = hash["label"]
      @prefix = hash["prefix"]
      @regex = hash["regex"]
      @internal_format = hash["internal_format"]
      @external_format = hash["external_format"]
    end
  end

  # Predicate (depricated as the TIO ID is introduced since 2022-02-08)
  class Edge
    attr_reader :label, :ns, :prefix, :predicate
    def initialize(hash)
      @label = hash["label"]
      @ns = hash["namespace"]
      @prefix = hash["prefix"]
      @predicate = hash["predicate"]
    end
  end

  # Relation
  class Link
    attr_reader :files, :fwd, :rev
    def initialize(hash)
      @files = ([] << hash["file"]).flatten
=begin 2022-02-08
      @fwd = Edge.new(hash["forward"]) if hash["forward"]
      @rev = Edge.new(hash["reverse"]) if hash["reverse"]
=end
      @fwd = hash["forward"] if hash["forward"]
      @rev = hash["reverse"] if hash["reverse"]
    end
  end
  
  class Update
    attr_reader :frequency, :method
    def initialize(hash)
      @frequency = hash["frequency"]
      @method = hash["method"]
    end
  end

  class Config
    class NoConfigError < StandardError; end

    attr_reader :source, :target, :link, :update
    def initialize(config_file)
      begin
        config = YAML.load(File.read(config_file))
        @path = File.dirname(config_file)
        @source_ns, @target_ns = File.basename(@path).split('-')
        @link = Link.new(config["link"])
        @update = Update.new(config["update"])
      rescue => error
        puts "Error: #{error.message}"
        exit 1
      end
      load_dataset
      setup_files
    end

    def load_dataset
      begin
        yaml_path = File.join(File.dirname(@path), 'dataset.yaml')
        unless File.exists?(yaml_path)
          yaml_path = './config/dataset.yaml'
        end
        @dataset = YAML.load(File.read(yaml_path))
        raise NoConfigError, @source_ns unless @dataset[@source_ns]
        raise NoConfigError, @target_ns unless @dataset[@target_ns]
        @source = Node.new(@dataset[@source_ns])
        @target = Node.new(@dataset[@target_ns])
      rescue NoConfigError => error
        puts "Error: dataset #{error.message} is not defined in the dataset.yaml file"
        exit 1
      end
    end

    def setup_files
      @tsv_dir = "output/tsv"
      @ttl_dir = "output/ttl"
      @tsv_file = "#{@tsv_dir}/#{@source_ns}-#{@target_ns}.tsv"
      @ttl_file = "#{@ttl_dir}/#{@source_ns}-#{@target_ns}.ttl"
      FileUtils.mkdir_p(@tsv_dir)
      FileUtils.mkdir_p(@ttl_dir)
    end

    def triple(s, p, o)
      [s, p, o, "."].join("\t")
    end

    def prefix
      prefixes = []
=begin 2022-02-08
      if @link.fwd
        prefixes << triple("@prefix", "#{@link.fwd.ns}:", "<#{@link.fwd.prefix}>")
      end
      if @link.rev and (! @link.fwd or (@link.fwd.ns != @link.rev.ns))
        prefixes << triple("@prefix", "#{@link.rev.ns}:", "<#{@link.rev.prefix}>")
      end
=end
      prefixes << triple("@prefix", "tio:", "<http://togoid.dbcls.jp/ontology#>")
      prefixes << triple("@prefix", "#{@source_ns}:", "<#{@source.prefix}>")
      prefixes << triple("@prefix", "#{@target_ns}:", "<#{@target.prefix}>")
      return prefixes
    end

    def exec_convert
      if File.exists?(@tsv_file)
        File.open(@ttl_file, "w") do |ttl_file|
          ttl_file.puts prefix
          ttl_file.puts
          tsv2ttl(@tsv_file, ttl_file)
        end
      else
        $stderr.puts "TogoID TSV file #{@tsv_file} not found. Run update first."
      end
    end

    def set_predicate(edge)
      if edge
=begin 2022-02-08
        "#{edge.ns}:#{edge.predicate}"  # e.g., rdfs:seeAlso
=end
        "tio:#{edge}"
      else
        false
      end
    end

    # Turtle spec: https://www.w3.org/TR/turtle/#sec-grammar-grammar
    #   * PN_LOCAL_ESC ::= '\' ('_' | '~' | '.' | '-' | '!' | '$' | '&' | "'" | '(' | ')' | '*' | '+' | ',' | ';' | '=' | '/' | '?' | '#' | '@' | '%')
    #   * 'a-b_c.d~e!f$g&h,i;j=k#l@m%n/o?p*q+r(s) AFFX-HUMGAPDH/M33197_3_at tX(XXX)D_tRNA'
    #   * => 'a\-b\_c\.d\~e\!f\$g\&h\,i\;j\=k\#l\@m\%n\/o\?p\*q\+r\(s\) AFFX\-HUMGAPDH\/M33197\_3\_at tX\(XXX\)D\_tRNA'
    # See also: http://docs.openlinksw.com/virtuoso/fn_ttlp_mt/
    #SED_PN_LOCAL_ESC = 's/[-_.~!$&,;=#@%\/\?\*\+\(\)]/\\\\&/g'
    SED_PN_LOCAL_ESC = 's/[~!$&,;=#@%\/\?\*\+\(\)]/\\\\&/g'

    def tsv2ttl(tsv, ttl)
      # To reduce method call
      fwd_predicate = set_predicate(@link.fwd)
      rev_predicate = set_predicate(@link.rev)
      # Should check whether source_id or target_id contains chars that need to be escaped in Turtle
      Kernel.open("| sed -e '#{SED_PN_LOCAL_ESC}' #{tsv}").each do |line|
        source_id, target_id, = line.strip.split(/\s+/)
        ttl.puts triple("#{@source_ns}:#{source_id}", "#{fwd_predicate}", "#{@target_ns}:#{target_id}") if fwd_predicate
        ttl.puts triple("#{@target_ns}:#{target_id}", "#{rev_predicate}", "#{@source_ns}:#{source_id}") if rev_predicate
      end
    end

    def exec_update
      ENV['PATH'] = [ File.expand_path('bin'), File.expand_path(@path), ENV['PATH'] ].join(':')
      File.open(@tsv_file, "w") do |tsv_file|
        Dir.chdir(@path) do
          IO.popen(@update.method) do |io|
            while buffer = io.gets
              tsv_file.puts buffer
            end
          end
        end
      end
    end

    def exec_check
      $stderr.puts pp(self)
      $stderr.puts
      puts prefix
      puts
      @link.files.each do |file|
        tsv2ttl("#{@path}/#{file}", $stdout)
      end
    end
  end

end
