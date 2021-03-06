require 'benchmark'
require 'gosu'

require_relative './monkey_patch'
require_rel './worlds/'

class Viewer < Gosu::Window

  class Key
    @keys = []

    class << self
      def keys
        @keys
      end

      def update_keys window
        @keys.each {|key| key.update window}
      end

      def post_update_keys window
        @keys.each {|key| key.post_update window}
      end
    end

    attr_reader :key, :last, :current

    def initialize key
      @key = key
      self.class.keys << self
    end

    def update window
      @current = window.button_down? key
    end

    def post_update window
      @last = @current
    end

    def was_released?
      last && !current
    end

    def was_pressed?
      current && !last
    end

    def is_down?
      current
    end

    def is_up?
      !current
    end
  end

  CAMERA_SPEED = 10
  SIZE_X = 80
  SIZE_Y = 80
  SIZE_Z = 20
  def initialize
    super(1300, 800, false)

    Gosu::enable_undocumented_retrofication

    @camera = Vector2.new(0,0)
    @generator = 5

    @zoom_modes = [0.25, 0.5, 1, 2, 4, 8, 16, 32]
    @zoom = 1


    @world = get_current_world.new(SIZE_X, SIZE_Y, SIZE_Z)
    make_world

    @time = 0

    @render_mode = :draw_easy

    @close_button = Key.new Gosu::KbEscape
    @next_view_button = Key.new Gosu::KbA
    @last_view_button = Key.new Gosu::KbS
    @draw_easy_button = Key.new Gosu::KbG
    @draw_hard_button = Key.new Gosu::KbH
    @rotate_cw_button = Key.new Gosu::KbW
    @rotate_ccw_button = Key.new Gosu::KbQ
    @zoom_in_button = Key.new Gosu::KbZ
    @zoom_out_button = Key.new Gosu::KbX
    @save_button = Key.new Gosu::KbE
    @randomize_button = Key.new Gosu::KbSpace
  end

  def update
    Key.update_keys self

    close if @close_button.is_down?
    @camera.x -= CAMERA_SPEED if button_down? Gosu::KbRight
    @camera.x += CAMERA_SPEED if button_down? Gosu::KbLeft

    @camera.y -= CAMERA_SPEED if button_down? Gosu::KbDown
    @camera.y += CAMERA_SPEED if button_down? Gosu::KbUp

    if @next_view_button.was_pressed?
      @generator += 1
      @generator = 0 if @generator > IsometricWorlds.count-1
      view = @world.view
      @world = get_current_world.new(SIZE_X, SIZE_Y, SIZE_Z)
      make_world
      @world.view = view
      force_redraw
    end

    if @last_view_button.was_pressed?
      @generator -= 1
      @generator = IsometricWorlds.count-1 if @generator < 0
      view = @world.view
      @world = get_current_world.new(SIZE_X, SIZE_Y, SIZE_Z)
      make_world

      @world.view = view
      force_redraw
    end

    if @draw_hard_button.was_pressed?
      @render_mode = :draw_hard
    end

    if @draw_easy_button.was_pressed?
      @render_mode = :draw_easy
    end

    if @rotate_ccw_button.was_pressed?
      @world.rotate_counter_clockwise
      force_redraw
    end

    if @rotate_cw_button.was_pressed?
      @world.rotate_clockwise
      force_redraw
    end

    if @zoom_in_button.was_pressed?
      @zoom += 1
      @zoom = @zoom_modes.length-1 if @zoom >= @zoom_modes.length
    end

    if @zoom_out_button.was_pressed?
      @zoom -= 1
      @zoom = 0 if @zoom < 0
    end

    if @save_button.was_pressed?
      world_path = File.absolute_path File.dirname(__FILE__) + "/../saves/#{get_current_world.to_s}/"
      Dir.mkdir(world_path)
      last_number = Dir.entries(world_path).map{|a| a.split(?.).first.to_i}.sort.last
      @image.save(world_path + "#{last_number}.png")
    end

    if @randomize_button.was_pressed?
      view = @world.view
      @world = get_current_world.new(SIZE_X, SIZE_Y, SIZE_Z)
      make_world
      @world.view = view
      force_redraw
    end

    self.caption = "ICG c:#{@camera.x},#{@camera.y} fps: #{Gosu.fps}, view: #{@world.view} g_t: #{@gen_time} d_t: #{@draw_time} world: #{get_current_world.to_s} gen: #{@generator}"

    Key.post_update_keys self
  end

  def make_world
    @gen_time = Benchmark.realtime do
      @world.make_world
    end
  end

  def get_current_world
    IsometricWorlds[IsometricWorlds.world_names[@generator]]
  end

  def draw
    #draw first
    send @render_mode
  end

  def draw_easy
    @image ||= record(1, 1) do
      #profiler = MethodProfiler.observe(IsometricFactory)
      @draw_time = Benchmark.realtime do
        @world.draw_world
      end
      #puts profiler.report.sort_by(:total_calls).order(:ascending)
    end
    translate(@camera.x * @zoom_modes[@zoom], @camera.y * @zoom_modes[@zoom]) do
      @image.draw(740, 190, 1, @zoom_modes[@zoom], @zoom_modes[@zoom])
    end
  end

  def draw_hard
    translate(@camera.x, @camera.y) do
      @world.draw_world
    end
  end

  def force_redraw
    @image = nil
  end
end

