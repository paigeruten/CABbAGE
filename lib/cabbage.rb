require 'midilib'

module Cabbage
  extend self

  class Song
    attr_accessor :title, :by, :key, :tempo, :time, :instruments, :voices

    def initialize
      @title = "Untitled"
      @by = "Anonymous"
      @key = Key.new("C+")
      @tempo = 120
      @time = 4..4
      @instruments = []
      @voices = []
      @length = 0
      @num_measures = 0
    end

    def title(t)
      @title = t
    end

    def by(name)
      @by = name
    end

    def key(k)
      @key = Key.new(k)
    end

    def tempo(t)
      @tempo = t
    end

    def time(t)
      @time = t
    end

    def instrument(symbol, name)
      instrument = Instrument.new(symbol, name)
      @instruments << instrument
    end

    def section(measures, measures_original = measures, &block)
      s = Section.new(@key, @time, @instruments, @voices, @num_measures)
      s.instance_eval(&block)

      section_length = (4.0 / @time.end) * @time.begin * measures
      @length += section_length
      @num_measures += measures

      (@voices - s.active_voices).each do |inactive_voice|
        inactive_voice << MeasureRest.new(measures)
      end

      if @voices.any? { |v| (v.calculate_length - @length).abs > 0.00001 }
        puts "Error: Your voices in measure(s) #{measures_original} should be #{section_length} quarter notes long:"
        puts
        @voices.each do |voice|
          puts "#{voice.instrument}: #{voice.calculate_length - (@length - section_length)}"
        end
        exit
      end
    end

    def measures(n, &block)
      section(n.end - n.begin + 1, n, &block)
    end

    def measure(n, &block)
      section(1, n, &block)
    end

    def write(filename = "out.mid")
      seq = MIDI::Sequence.new

      info_track = MIDI::Track.new(seq)
      seq.tracks << info_track
      info_track.events << MIDI::Tempo.new(MIDI::Tempo.bpm_to_mpq(@tempo))
      info_track.events << MIDI::MetaEvent.new(MIDI::META_SEQ_NAME, "#{@title} by #{@by}")

      if @voices.length > 16
        puts "Error: too many voices. Maximum is 16. You have #{@voices.length}."
        exit
      end

      @voices.each_with_index do |voice, channel|
        voice_track = MIDI::Track.new(seq)
        seq.tracks << voice_track
        voice_track.name = "Voice #{channel}"
        voice_track.instrument = voice.instrument.name

        voice_track.events << MIDI::Controller.new(channel, MIDI::CC_VOLUME, 127)

        voice_track.events << MIDI::ProgramChange.new(channel, voice.instrument.program, 0)

        rest = 0

        voice.each do |note|
          length = seq.length_to_delta(note.calculate_length(@time))

          if note.is_a?(Rest) || note.is_a?(MeasureRest)
            rest += length
          else
            if rest > 0
              length_offset = rest
              rest = 0
            else
              length_offset = 0
            end

            tone = note.tone

            if note.accented
              velocity = 75
            else
              velocity = 63
            end

            if note.articulation == :staccato
              rest += length - seq.note_to_delta("32nd")
              length = seq.note_to_delta("32nd")
            end

            voice_track.events << MIDI::NoteOn.new(channel, tone, velocity, length_offset)
            voice_track.events << MIDI::NoteOff.new(channel, tone, velocity, length)
          end
        end
      end

      File.open(filename, "wb") do |file|
        seq.write(file)
      end

      puts "Written to #{filename}"
    end
  end

  class Key
    KEYS = {
      "C+"  => %w(),
      "G+"  => %w(f#),
      "D+"  => %w(f# c#),
      "A+"  => %w(f# c# g#),
      "E+"  => %w(f# c# g# d#),
      "B+"  => %w(f# c# g# d# a#),
      "F#+" => %w(f# c# g# d# a# e#),
      "F+"  => %w(bb),
      "Bb+" => %w(bb eb),
      "Eb+" => %w(bb eb ab),
      "Ab+" => %w(bb eb ab db),
      "Db+" => %w(bb eb ab db gb),
      "Gb+" => %w(bb eb ab db gb cb),
    }

    RELATIVE_MAJORS = {
      "a-" => "C+",
      "e-" => "G+",
      "b-" => "D+",
      "f#-" => "A+",
      "c#-" => "E+",
      "g#-" => "B+",
      "d#-" => "F#+",
      "eb-" => "Gb+",
      "bb-" => "Db+",
      "f-" => "Ab+",
      "c-" => "Eb+",
      "g-" => "Bb+",
      "d-" => "F+"
    }

    attr_accessor :name, :signature, :accidental

    def initialize(name)
      @name = name

      major_key = (name[-1] == ?-) ? RELATIVE_MAJORS[name] : name
      if @signature = KEYS[major_key]
        @accidental = @signature.empty? ? "" : @signature.first[-1]
      else
        raise "Invalid key '#{name}'"
      end
    end

    def accidental_for(note)
      if @signature.include? "#{note}#{@accidental}"
        @accidental
      else
        ""
      end
    end
  end

  class Instrument
    attr_accessor :symbol, :name, :program

    def initialize(symbol, name)
      @symbol, @name, @program = symbol.to_sym, name.to_s, MIDI::GM_PATCH_NAMES.index(name)

      if @program.nil?
        puts "Error: can't find instrument '#{name}'."
        exit
      end
    end
  end

  class Voice < Array
    attr_accessor :instrument, :time, :length

    def initialize(instrument, time)
      @instrument, @time = instrument, time
    end

    def calculate_length
      length = 0
      each do |note|
        length += note.calculate_length(@time)
      end
      length
    end
  end

  class Section
    attr_accessor :key, :voices, :active_voices

    def initialize(key, time, instruments, voices, num_measures)
      @key, @time, @instruments, @voices, @num_measures = key, time, instruments, voices, num_measures
      @active_voices = []
    end

    def voice(instrument_symbol, track, options = {})
      options[:default_note] ||= @time.end

      instrument = @instruments.find { |ins| ins.symbol == instrument_symbol.to_sym }

      if instrument.nil?
        puts "Error: undefined instrument '#{instrument_symbol}'."
        exit
      end

      voice = (@voices - @active_voices).find { |v| v.instrument == instrument }

      if voice.nil?
        voice = Voice.new(instrument, @time)
        voice << MeasureRest.new(@num_measures)
        @voices << voice
      end

      @active_voices << voice

      current_octave = 4
      track.split.each do |note|
        if note == "+"
          current_octave += 1
          note = nil
        elsif note == "-"
          current_octave -= 1
          note = nil
        elsif note =~ /^(\d+\.*:?)?&$/
          note = Rest.new($1 || options[:default_note].to_s)
        elsif note =~ /^(\d+\.*:?)?([a-g])([b#n])?([\^v]*)(>)?([(\-])?$/
          duration = $1 || "#{options[:default_note]}:"
          letter = $2
          accidental = $3 ? ($3 if $3 != ?n).to_s : @key.accidental_for($2)
          octave = $4.empty? ? current_octave : (current_octave + $4.length * {?^=>1,?v=>-1}[$4[0]]).to_i
          accented = ($5 == ">")
          articulation = ((options[:staccato] && $6 != "(") || $6 == "-") ? :staccato : :legato

          note = Note.new(duration, letter, accidental, octave, accented, articulation)
        else
          puts "Error: couldn't parse note '#{note}'"
          exit
        end

        voice << note if note
      end
    end

    def method_missing(name, *args)
      if @instruments.find { |ins| ins.symbol == name.to_sym }
        voice(name, *args)
      else
        super
      end
    end
  end

  class Note
    attr_accessor :duration, :letter, :accidental, :octave, :accented, :articulation

    def initialize(duration, letter, accidental, octave, accented, articulation)
      @duration, @letter, @accidental, @octave, @accented, @articulation = duration, letter, accidental, octave, accented, articulation
    end

    def tone
      tone = { :c => 0, :d => 2, :e => 4, :f => 5, :g => 7, :a => 9, :b => 11 }[@letter.downcase.to_sym]
      tone += { "" => 0, "#" => 1, "b" => -1 }[@accidental]

      octave = @octave
      if tone == 12
        tone = 0
        octave += 1
      elsif tone == -1
        tone = 11
        octave -= 1
      end

      64 + ((octave - 4) * 12) + tone
    end

    def calculate_length(time = nil)
      dots = @duration[/\.+/].to_s.length
      duration = @duration[/\d+/]
      length = 4.0 / duration.to_i

      length + length * (1 - 1.0 / (1 << dots))
    end

    def to_s
      "#{@duration}:#{@letter}#{@accidental}#{@octave}#{'>' if @accented}#{@articulation}"
    end
  end

  class Rest < Note
    def initialize(duration)
      super(duration, nil, nil, nil, nil, nil)
    end

    def to_s
      @duration.to_s
    end
  end

  class MeasureRest < Note
    attr_accessor :measures

    def initialize(measures = 1)
      super(nil, nil, nil, nil, nil, nil)
      @measures = measures
    end

    def calculate_length(time)
      beat_length = 4.0 / time.end.to_i
      beat_length * time.begin * @measures
    end

    def to_s
      "|#{@measures}|"
    end
  end

  def song(&block)
    s = Song.new
    s.instance_eval(&block)
    s
  end
end
