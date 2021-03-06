require 'rmagick'
require 'gosu'

require_relative './isometric_asset'
require_relative './texture_stitcher'
require_relative '../data/vector'
require_relative '../monkey_patch'

class IsometricAssets
  attr_reader :block_texture, :tile_texture, :config

  attr_reader :assets, :collections
  attr_reader :block_width, :block_height

  def initialize(name)
    @assets = {blocks: {}, tiles: {}}
    @collections = {}

    open_content name
  end

  def home_path
    File.absolute_path(File.dirname(File.absolute_path(__FILE__ )) + '/../../')
  end

  def content_path
    home_path  + "/content/"
  end

  def cache_path
    home_path + "/cache/"
  end

  def saves_path
    home_path + "/saves/"
  end

  def open_content(assets_name)
    asset_path = content_path + "#{assets_name}/"
    tiles_asset_path = asset_path + "tiles/"
    blocks_asset_path = asset_path + "blocks/"

    tile_texture_path = asset_path + "tiles.png"
    block_texture_path = asset_path + "blocks.png"

    texture_config_path = asset_path + "config.yml"

    @config = read_texture_config(texture_config_path)

    TextureStitcher.stitch(combine_texture_files(:tiles, tiles_asset_path)).write(tile_texture_path)
    TextureStitcher.stitch(combine_texture_files(:blocks, blocks_asset_path)).write(block_texture_path)

    @block_texture = Gosu::Image.new(block_texture_path)
    @tile_texture = Gosu::Image.new(tile_texture_path)

    map_textures
  end

  def combine_texture_files(type, type_asset_path)
    assets_col_to_stitch = []
    current_col = 0

    # find all files from content directory
    Dir.entries(type_asset_path).each do |asset_name|
      next if asset_name =~ /^\.*$/ #Returns . and . .as folders
      next if asset_name == "config.yml"
      next if asset_name.chars.first == ?_
      next unless File.directory?(type_asset_path + asset_name)


      asset_name = asset_name.to_sym
      puts "loading /#{type}/#{asset_name}"

      #try to assign images if they exist
      asset_path = type_asset_path + "#{asset_name}/"
      asset_config_path = asset_path + "config.yml"
      next unless File.exist?(asset_config_path)

      assets_row_to_stitch = []
      current_row = 0

      assets[type][asset_name] = IsometricAsset.new(self, type, asset_name)
      assets[type][asset_name].read_config(asset_config_path)

      # Add collections
      asset_config_file = File.open(asset_config_path, "r")
      collections = YAML.load(asset_config_file.read)['collections'].map(&:to_sym)
      asset_config_file.close

      collections.each do |collection|
        if @collections[collection].nil?
          @collections[collection] = [asset_name]
        else
          @collections[collection] << asset_name
        end
      end



      Dir.entries(asset_path).each do |asset_file|
        next if asset_file =~ /^\.*$/ #Returns . and . .as folders
        next if asset_file == "config.yml"
        next if asset_file.chars.first == ?_
        next unless asset_file =~ /\.png$/

        asset_tag = asset_file.split(?.)[0].to_sym
        subimage_pos = Vector2.new(current_row, current_col)

        assets[type][asset_name][asset_tag] = subimage_pos

        assets_row_to_stitch << asset_path + asset_file

        current_row += 1
      end
      assets_col_to_stitch << assets_row_to_stitch
      current_col += 1
    end

    assets_col_to_stitch
  end

  def map_textures
    tile_width = config[:tile_width]
    tile_height = config[:tile_height]
    block_width = config[:block_width]
    block_height = config[:block_height]

    assets.each do |type, type_assets|
      type_assets.each do |asset_name, isometric_asset|
        isometric_asset.tags.each do |asset_tag, asset_texture_position|
          if type == :blocks
            assets[type][asset_name][asset_tag] =
              @block_texture.subimage(block_width*asset_texture_position.x, block_height*asset_texture_position.y, block_width, block_height)
          elsif type == :tiles
            assets[type][asset_name][asset_tag] =
              @tile_texture.subimage(tile_width*asset_texture_position.x, tile_height*asset_texture_position.y, tile_width, tile_height)
          end
        end
      end
    end
  end

  def read_texture_config(config_yml)
    #read the texture config files in (YAML)
    file = File.open(config_yml, "r")
    yaml_dump = Hash.keys_to_sym YAML.load(file.read)
    file.close
    @config = yaml_dump
  end

  def [] type
    if type == :blocks
      assets[:blocks]
    elsif type == :tiles
      assets[:tiles]
    else
      fail
    end
  end

  def draw_tile(tile, view, position)
    return unless tile.type
    tile_asset = self[:tiles][tile.type]
    tile_asset.draw_asset(position.x,  position.y, tile.color, view, tile.rotation)
  end

  def draw_block(block, view, position)
    return unless block.type
    block_asset = self[:blocks][block.type]
    block_asset.draw_asset(position.x,  position.y, block.color, view, block.rotation)
  end

  def tile_width
    config[:tile_width]
  end
  def tile_height
    config[:tile_height]
  end

  def block_width
    config[:block_width]
  end
  def block_height
    config[:block_height]
  end

end