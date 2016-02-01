require 'rubygems'
require 'bundler/setup'

require 'awesome_print'
require 'byebug'
require 'json'
require 'open-uri'
require 'gender_detector'

class PublicArt
  attr_accessor :keys, :data

  def initialize(data, file)
    @data         = JSON.load(data)
    @keys         = get_keys
    @artist_count = get_artist_count
    @file         = file
  end

  def to_tab
    out = []
    @file.puts [@keys, "AnneeAccession", get_artist_keys].flatten.join("\t")
    @data.each do |work|

      partial_work = @keys.map do |key|
        value = work[key]

        if key.match(/^Date/)
          # Translate dates from the data's weird format
          date_from_asp_net(value).strftime("%Y/%m/%d") unless value.nil?

        elsif key.match(/^AdresseCivique/)
          # Remove \r and \n from the data and replace with ","
          value.gsub(/\r|\n/, ', ') unless value.nil?

        elsif key.match(/^Mediums/)
          # Not enough infos to be useful
          nil

        else
          # Replace \r and \n by spaces
          value.to_s.gsub(/\r|\n/, ' ') unless value.nil?
        end
      end

      partial_work << calculate_acquisition_year(work)
      partial_work << get_artist_data(work)
      @file.puts partial_work.join("\t")
    end
  end

  private

  def get_artist_data(work)
    artists = []
    @artist_count.times do |n|
      if work["Artistes"][n]
        artists << work["Artistes"][n]["Prenom"]
        artists << work["Artistes"][n]["Nom"]
        artists << work["Artistes"][n]["NomCollectif"]
      end
    end
    return artists
  end

  def get_artist_keys
    keys = []
    @artist_count.times do |n|
      keys << "Prenom#{n}"
      keys << "Nom#{n}"
      keys << "NomCollectif#{n}"
    end
    return keys
  end

  def calculate_acquisition_year(work)
    date_from_asp_net(work["DateAccession"]).year if work["DateAccession"]
  end

  def get_keys
    keys = []
    @data.each do |work|
      keys << work.keys
    end
    keys = keys.flatten.uniq
    keys.delete("Artistes") # We'll handle this case manually
    return keys
  end

  def get_artist_count
    largest_count = 0
    @data.each do |work|
      count = work["Artistes"].count
      largest_count = count if count > largest_count
    end

    return largest_count
  end

  # Stolen from http://stackoverflow.com/questions/11781223/parsing-net-datetime-in-ruby-javascript
  def date_from_asp_net(asp_net_date)
    date_pattern = /\/Date\((-?\d+)(\-\d+)?\)\//
    _, date, timezone = *date_pattern.match(asp_net_date)
    date = (date.to_i / 1000).to_s
    DateTime.strptime(date + timezone, '%s%z')
  end
end

class PublicArtists
  def initialize(data, file)
    @data         = JSON.load(data)
    @gender       = GenderDetector.new
    @file         = file
    @i18n = {
      :andy => "indéterminé",
      :male => "homme",
      :mostly_male => "homme",
      :female => "femme",
      :mostly_female => "femme"
    }
  end

  def to_tab
    @file.puts ["Nom", "Prenom", "NomCollectif", "Genre"].join("\t")
    artists = []
    @data.each do |work|
      work["Artistes"].each do |artist|
        out = []
        out << artist["Nom"]
        out << artist["Prenom"]
        out << artist["NomCollectif"]
        out << @i18n[@gender.get_gender(artist["Prenom"])] if artist["Prenom"]

        artists << out.join("\t")
      end
    end
    @file.puts artists.compact.uniq.join("\n")
  end
end

url = "http://donnees.ville.montreal.qc.ca/dataset/2980db3a-9eb4-4c0e-b7c6-a6584cb769c9/resource/18705524-c8a6-49a0-bca7-92f493e6d329/download/oeuvresdonneesouvertes.json"
PublicArt.new(open(url).read, File.open("./oeuvres.tab", "w")).to_tab
PublicArtists.new(open(url).read, File.open("./artistes.tab", "w")).to_tab