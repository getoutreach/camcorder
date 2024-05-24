module Camcorder

  #
  # Proxy which records all external methods
  #
  class Proxy
    
    attr_reader :klass
    attr_reader :instance
    attr_reader :recorder
    attr_reader :side_effects
    
    def initialize(recorder, klass, *args)
      @klass = klass
      @init_args = args
      @recorder = recorder
      puts "INIT side effects: #{@init_args}"
      _add_side_effects(@init_args)
    end
    
    def _initialize
      @instance ||= klass.new(*@init_args)
    end
    
    def _add_side_effects(args)
      @side_effects = _hash_with_side_effects(args).tap do |x|
        puts "SETTING side effects to '#{x}'"
      end
    end
    
    def _hash_args(args)
      # libyaml 0.2.5 helpfully removes trailing whitespace.  Previous versions
      # did not do this.  Previous recordings were made involving hashes that
      # included that stray whitespace.
      #
      # This here hack holds things together, barely, for now.
      ick = YAML.dump(args).gsub(/^\-$/, '- ')
      Digest::MD5.hexdigest(ick)
    end
    
    def _hash_with_side_effects(args)
      if side_effects
        args = args + [side_effects]
      end
      _hash_args(args)
    end
    
    def _record(name, args, &block)
      hash = _hash_with_side_effects(args)
      key = "#{klass.name}-#{name}-#{hash}"
      recorder.record key do
        yield
      end
    rescue PlaybackError => e
      raise ProxyPlaybackError.new(klass, name, args, side_effects)
    rescue RecordingError => e
      raise ProxyRecordingError.new(klass, name, args, side_effects)
    end
    
    def method_missing(name, *args)
      _record(name, args) do
        _initialize.send name, *args
      end
    end
    
    def respond_to?(name)
      super || _initialize.respond_to?(name)
    end
    
    #
    # These methods have "side effects" and will cause subsequent invocations of
    # all methods to be re-recorded.
    #
    def self.methods_with_side_effects(*names)
      names.each do |name|
        define_method name do |*args|
          puts "ADDING side effects for '#{name}': #{args}"
          _add_side_effects(args)
          method_missing(name, *args)
        end
      end
    end
    
  end

end
