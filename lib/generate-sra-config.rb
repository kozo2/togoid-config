#!/usr/bin/env ruby
# Config generator for SRA/BioProject/BioSample ID relations
require 'yaml'
require 'fileutils'

module Accessions
  class GenerateConfig
    class << self
      @@config_dir_path = File.join(File.dirname($0), "..", "link")
      @@accession_tab_path = "ftp.ncbi.nlm.nih.gov/sra/reports/Metadata/SRA_Accessions.tab"

      def nodes
        {
          "sra.accession" => {
            "label" => "SRA Accessions",
            "type" => "DataSet",
            "namespace" => "sra.accession",
            "prefix" => "http://identifiers.org/insdc.sra/"
          },
          "sra.experiment" => {
            "label" => "SRA Experiment",
            "type" => "DataSet",
            "namespace" => "sra.experiment",
            "prefix" => "http://identifiers.org/insdc.sra/"
          },
          "sra.project" => {
            "label" => "SRA Project",
            "type" => "DataSet",
            "namespace" => "sra.project",
            "prefix" => "http://identifiers.org/insdc.sra/"
          },
          "sra.sample" => {
            "label" => "SRA Sample",
            "type" => "DataSet",
            "namespace" => "sra.sample",
            "prefix" => "http://identifiers.org/insdc.sra/"
          },
          "sra.run" => {
            "label" => "SRA Run",
            "type" => "DataSet",
            "namespace" => "sra.run",
            "prefix" => "http://identifiers.org/insdc.sra/"
          },
          "sra.analysis" => {
            "label" => "SRA Analysis",
            "type" => "DataSet",
            "namespace" => "sra.analysis",
            "prefix" => "http://identifiers.org/insdc.sra/"
          },
          "bioproject" => {
            "label" => "BioProject",
            "type" => "DataSet",
            "namespace" => "bioproject",
            "prefix" => "http://identifiers.org/bioproject/"
          },
          "biosample" => {
            "label" => "BioSample",
            "type" => "DataSet",
            "namespace" => "biosample",
            "prefix" => "http://identifiers.org/biosample/"
          },
        }
      end

      def nodes_links
        [
          {
            from: "sra.accession",
            to: "sra.project",
            method: parse_accession_tab("RP", 2, 1),
          },
          {
            from: "sra.accession",
            to: "sra.experiment",
            method: parse_accession_tab("RX", 2, 1),
          },
          {
            from: "sra.accession",
            to: "sra.sample",
            method: parse_accession_tab("RS", 2, 1),
          },
          {
            from: "sra.accession",
            to: "sra.run",
            method: parse_accession_tab("RR", 2, 1),
          },
          {
            from: "sra.accession",
            to: "sra.analysis",
            method: parse_accession_tab("RZ", 2, 1),
          },
          {
            from: "sra.accession",
            to: "biosample",
            method: parse_accession_tab("RS", 2, 18),
          },
          {
            from: "sra.accession",
            to: "bioproject",
            method: parse_accession_tab("RP", 2, 19),
          },
          {
            from: "sra.experiment",
            to: "sra.sample",
            method: parse_accession_tab("RX", 1, 12),
          },
          {
            from: "sra.experiment",
            to: "sra.project",
            method: parse_accession_tab("RX", 1, 13),
          },
          {
            from: "sra.experiment",
            to: "biosample",
            method: parse_accession_tab("RX", 1, 18),
          },
          {
            from: "sra.experiment",
            to: "bioproject",
            method: parse_accession_tab("RX", 1, 19),
          },
          {
            from: "sra.run",
            to: "sra.experiment",
            method: parse_accession_tab("RR", 1, 11),
          },
          {
            from: "sra.run",
            to: "sra.sample",
            method: parse_accession_tab("RR", 1, 12),
          },
          {
            from: "sra.run",
            to: "sra.project",
            method: parse_accession_tab("RR", 1, 13),
          },
          {
            from: "sra.run",
            to: "biosample",
            method: parse_accession_tab("RR", 1, 18),
          },
          {
            from: "sra.run",
            to: "bioproject",
            method: parse_accession_tab("RR", 1, 19),
          },
          {
            from: "sra.project",
            to: "bioproject",
            method: parse_accession_tab("RP", 1, 19),
          },
          {
            from: "sra.sample",
            to: "biosample",
            method: parse_accession_tab("RS", 1, 18),
          },
        ]
      end

      def parse_accession_tab(prefix, col_from, col_to)
        fname = File.basename(@@accession_tab_path)
        tmpf = "/tmp/togoid/#{fname}"
        "[ $(ls -l #{tmpf} | awk '{ print $5 }') -eq $(curl -sI #{@@accession_tab_path} | grep 'Content-Length' | tr -d '\r' | awk '{ print $2 }') ] || (mkdir -p $(dirname #{tmpf}) && curl -s #{@@accession_tab_path} > #{tmpf}) && awk 'BEGIN{ FS=OFS=\"\t\" } $1 ~ /^.#{prefix}/ { print $#{col_from}, $#{col_to} }' #{tmpf} | grep -v '-'"
      end

      def link_attribute
        {
          "label" => "seeAlso",
          "namespace" => "rdfs",
          "prefix" => "http://www.w3.org/2000/01/rdf-schema#",
          "predicate" => "seeAlso",
        }
      end

      def generate
        iterate(:generate)
      end

      def generate_test
        iterate(:generate_test)
      end

      def remove
        iterate(:remove)
      end

      def iterate(command)
        nodes_links.each do |link|
          s_id = link[:from]
          t_id = link[:to]
          pair_id = "#{s_id}-#{t_id}"

          case command
          when :generate
            generate_config(pair_id, s_id, nodes[s_id], t_id, nodes[t_id], link[:method])
          when :remove
            remove_dirs(pair_id)
          end
        end
      end

      def generate_config(pair_id, s_id, s_attrs, t_id, t_attrs, method)
        data = {
          "source" => s_attrs,
          "target" => t_attrs,
          "link" => {
            "file" => File.join(".", "#{pair_id}.tsv"),
            "forward" => link_attribute,
            "reverse" => link_attribute,
          },
          "update" => {
            "frequency" => "Daily",
            "method" => "#{method} > pair.tsv",
          }
        }
        create(pair_id, data)
      end

      def create(pair_id, data)
        config_filepath = File.join(@@config_dir_path, pair_id, "config.yaml")
        FileUtils.mkdir_p(File.dirname(config_filepath))
        open(config_filepath, "w"){|f| f.puts(YAML.dump(data)) }
      end

      def remove_dirs(pair_id)
        FileUtils.rm_rf(File.join(@@config_dir_path, pair_id))
      end
    end
  end
end

if __FILE__ == $0
  case ARGV[0]
  when "--rm"
    Accessions::GenerateConfig.remove
  else
    Accessions::GenerateConfig.generate
  end
end
