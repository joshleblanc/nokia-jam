$gtk.disable_controller_config

# Logical canvas width and height
WIDTH = 1280
HEIGHT = 720

# Nokia screen dimensions
NOKIA_WIDTH = 84
NOKIA_HEIGHT = 48

# Determine best fit zoom level
ZOOM_WIDTH = (WIDTH / NOKIA_WIDTH).floor
ZOOM_HEIGHT = (HEIGHT / NOKIA_HEIGHT).floor
ZOOM = [ZOOM_WIDTH, ZOOM_HEIGHT].min

# Compute the offset to center the Nokia screen
OFFSET_X = (WIDTH - NOKIA_WIDTH * ZOOM) / 2
OFFSET_Y = (HEIGHT - NOKIA_HEIGHT * ZOOM) / 2

# Compute the scaled dimensions of the Nokia screen
ZOOMED_WIDTH = NOKIA_WIDTH * ZOOM
ZOOMED_HEIGHT = NOKIA_HEIGHT * ZOOM

# to generate a song
# CM = %w[c1 e1 g1]
# GM = %w[g1 b1 d1]
# Am = %w[a1 c1 e1]
# FM = %w[f1 a1 c1]

SONG = %w[g1 d1 g2 d1 f#1 d1 a1 d2 nil g1 d1 g2 d1 c1 e1 c1 b1 nil e1 c1 g1 c1 e1]
#CHORDS = [CM, GM, Am, FM] * 4

# CHORDS.each do |chord|
#   SONG.push *chord.shuffle
# end
# SONG.each_with_index do |chord, index|
#   if rand < 0.1
#     SONG[index] = nil
#   end
# end
p SONG
NOTES = SONG #["e1", "e1", "g1", nil, "c1", "e1", "e1", nil, "c1", "c1", "b1", nil, "d1", "f1", "c1", nil, "f1", "c1", "c1", nil, "g1", "g1", "b1", nil, "g1", "b1", "f1", nil, "f1", "g1", "d1", nil, "a1", "b1", "a1", nil, "a1", "e1", "a1", nil, "c1", "c1", "a1", nil, "c1", "g1", "a1"]
#TEST = NOTES #24.times.map { NOTES.sample }

PALLETTE = {
  primary: {
    r: 78,
    g: 94,
    b: 85
  },
  secondary: {
    r: 26,
    g: 32,
    b: 24
  },
}

STATUS_BAR_H = 12
BUILDING_SIZE = 16

# Define building types
BUILDINGS = [
  {
    name: "House",
    short_name: "Hou.",
    base_cost: 10,
    income: 1,
    visible_threshold: 0
  },
  {
    name: "Windmill",
    short_name: "Win.",
    base_cost: 150,
    income: 10,
    visible_threshold: 5
  },
  {
    name: "Shop",
    short_name: "Sho.",
    base_cost: 1000,
    income: 50,
    visible_threshold: 50
  },
  {
    name: "Store",
    short_name: "Sto.",
    base_cost: 5000,
    income: 200,
    visible_threshold: 250
  },
  {
    name: "Factory",
    short_name: "Fac.",
    base_cost: 20000,
    income: 1000,
    visible_threshold: 1000
  },
  {
    name: "Bank",
    short_name: "Ban.",
    base_cost: 100000,
    income: 5000,
    visible_threshold: 5000
  },
  {
    name: "Tower",
    short_name: "Tow.",
    base_cost: 500000,
    income: 20000,
    visible_threshold: 25000
  },
  {
    name: "Castle",
    short_name: "Cas.",
    base_cost: 2000000,
    income: 100000,
    visible_threshold: 100000
  },
  {
    name: "Kingdom",
    short_name: "Kin.",
    base_cost: 10000000,
    income: 500000,
    visible_threshold: 500000
  }
]

def start_game(args)
  return if load_game(args)

  args.state = {
    money: 0,
    income_per_second: 0,
    time: 0,
    view: :main,
    confirm_open: false,
    confirm_selection: 0,
    selection: {
      idx: 0
    },
    buildings: [],
    manual_clicks: [],
    manual_income_rate: 0,
    hint_visibility: 10,
    jingle_timer: 0,
    jingle_note: 0
  }
  
  BUILDINGS.each do |building_type|
    args.state.buildings << {
      name: building_type.name,
      short_name: building_type.short_name,
      cost: building_type.base_cost,
      income: building_type.income,
      base_cost: building_type.base_cost,
      count: 0,
      visible_threshold: building_type.visible_threshold
    }
  end
end

def boot(args)
  args.state = {
    view: :menu,
    menu_selection: 0,
    jingle_note: 0,
    jingle_timer: 0
  }
end

def shutdown(args)
  save_game(args)
end

def tick(args)
  args.outputs.background_color = [0, 0, 0]

  args.outputs[:nokia].w = 84
  args.outputs[:nokia].h = 48
  args.outputs[:nokia].background_color = PALLETTE[:secondary]

  args.state.nokia_mouse_position = {
    x: (args.inputs.mouse.x - OFFSET_X).idiv(ZOOM),
    y: (args.inputs.mouse.y - OFFSET_Y).idiv(ZOOM),
    w: 1,
    h: 1,
  }

  if args.state.view == :game 
    process_passive_income(args)

    if args.state.confirm_open
      handle_confirm_input(args)
    else
      handle_main_input(args)
    end
  
    render_status_bar(args)
    render_buildings(args)
    
    if args.state.confirm_open
      render_confirm(args)
    end
  elsif args.state.view == :menu
    handle_menu_input(args)
    render_menu(args)
  elsif args.state.view == :help
    handle_help_input(args)
    render_help(args)
  end
  

  # Render the Nokia screen to the main output
  args.outputs.sprites << {
    x: OFFSET_X,
    y: OFFSET_Y,
    w: ZOOMED_WIDTH,
    h: ZOOMED_HEIGHT,
    path: :nokia
  }

  if args.state.sound_to_play 
    args.audio[:sound] = { input: args.state.sound_to_play }
    args.state.sound_to_play = nil
  elsif args.state.jingle_timer == 0
    music = SONG
    args.audio[:sound] = { input: "sounds/nokia_3310_composer/#{music[args.state.jingle_note]}.wav" }
    args.state.jingle_note += 1
    args.state.jingle_note = 0 if args.state.jingle_note >= music.length
    args.state.jingle_timer = 16
  else
    args.state.jingle_timer -= 1
  end
end

def save_game(args)
  return if args.state.view != :game

  args.state.confirm_open = false 
  args.state.confirm_block = nil
  args.state.confirm_message = nil
  args.state.confirm_result = nil
  $gtk.serialize_state("savegame.txt", args.state)
end

def load_game(args)
  parsed_state = $gtk.deserialize_state("savegame.txt")
  if parsed_state
    args.state = parsed_state
    return true
  else
    return false
  end
end

def handle_menu_input(args)
  if args.inputs.keyboard.key_down.up 
    args.state.menu_selection -= 1
    args.state.menu_selection = args.state.menu_selection.clamp(0, 1)
  elsif args.inputs.keyboard.key_down.down
    args.state.menu_selection += 1
    args.state.menu_selection = args.state.menu_selection.clamp(0, 1)
  elsif args.inputs.keyboard.key_down.space
    if args.state.menu_selection == 0
      start_game(args)
      args.state.view = :game
    elsif args.state.menu_selection == 1
      args.state.view = :help
    end
  end
end

def handle_help_input(args)
  if args.inputs.keyboard.key_down.space
    args.state.view = :menu
  end
end

def render_help(args)
  lines = ["SPACE -", "    Confirm Selection", "Arrow keys -", "    Move selection", "G - Generate money"]
  lines.each_with_index do |line, index|
    nokia.primitives << {
      x: 1,
      y: NOKIA_HEIGHT - index * 7,
      text: line,
      **PALLETTE[:primary],
      size_px: 6,
      font: "tiny.ttf",
      primitive_marker: :label
    }
  end

  nokia.primitives << { 
    x: 36, y: 8,
    text: "BACK",
    **PALLETTE[:primary],
    size_px: 6,
    font: "tiny.ttf",
    primitive_marker: :label
  }

  nokia.primitives << {
    x: 32, y: 1,
    w: 24,
    h: 8,
    **PALLETTE[:primary],
    primitive_marker: :border
  }
end

def render_menu(args)
  nokia.primitives << {
    x: 2, y: NOKIA_HEIGHT,
    text: "TOWN",
    **PALLETTE[:primary],
    size_px: 12,
    font: "tiny.ttf",
    primitive_marker: :label
  }
  nokia.primitives << {
    x: 16, y: NOKIA_HEIGHT - 10,
    text: "GRINDER",
    **PALLETTE[:primary],
    size_px: 12,
    font: "tiny.ttf",
    primitive_marker: :label
  }

  nokia.primitives << {
    x: NOKIA_WIDTH / 2 - (NOKIA_WIDTH / 2) / 2, y: 1,
    w: NOKIA_WIDTH / 2,
    h: NOKIA_HEIGHT - 24,
    **PALLETTE[:primary],
    primitive_marker: :solid
  }

  nokia.primitives << {
    x: 34, y: 20,
    w: NOKIA_WIDTH / 4,
    h: 8,
    **PALLETTE[:secondary],
    primitive_marker: :label,
    text: "PLAY",
    size_px: 6,
    font: "tiny.ttf"
  }

  nokia.primitives << {
    x: 34, y: 12,
    w: NOKIA_WIDTH / 4,
    h: 8,
    **PALLETTE[:secondary],
    primitive_marker: :label,
    text: "HELP",
    size_px: 6,
    font: "tiny.ttf"
  }

  nokia.primitives << {
    x: 32, y: (args.state.menu_selection == 0 ? 20 : 12) - 7,
    w: NOKIA_WIDTH / 4,
    h: 8,
    **PALLETTE[:secondary],
    primitive_marker: :border,
  }
end

def nokia 
  $args.outputs[:nokia]
end

def calculate_cost(base_cost, count, multiplier = 1.15)
  (base_cost * (multiplier ** count)).to_i
end

def handle_confirm_input(args)
  if args.inputs.keyboard.key_down.left || args.inputs.keyboard.key_down.up
    args.state.confirm_selection = 0
  elsif args.inputs.keyboard.key_down.right || args.inputs.keyboard.key_down.down
    args.state.confirm_selection = 1
  elsif args.inputs.keyboard.key_down.space
    process_confirm(args)
  end
end

def visible_buildings
  $args.state.buildings.select { |b| $args.state.income_per_second >= b.visible_threshold || b[:count] > 0 }
end

def play_sound(what)
  $args.state.sound_to_play = what
end

def handle_main_input(args)  
  # Calculate grid layout dimensions
  columns = 3
  rows = (visible_buildings.length / columns.to_f).ceil
  
  if args.inputs.keyboard.key_down.left
    args.state.selection.idx = (args.state.selection.idx - 1) % visible_buildings.length
  elsif args.inputs.keyboard.key_down.right
    args.state.selection.idx = (args.state.selection.idx + 1) % visible_buildings.length
  elsif args.inputs.keyboard.key_down.up
    args.state.selection.idx = (args.state.selection.idx - columns) % visible_buildings.length
  elsif args.inputs.keyboard.key_down.down
    args.state.selection.idx = (args.state.selection.idx + columns) % visible_buildings.length
  elsif args.inputs.keyboard.key_down.space
    process_building_select(args)
    play_sound "sounds/nokia_soundpack_@trix/blip5.wav"
  elsif args.inputs.keyboard.key_down.g
    # Generate 1 money when pressing G
    args.state.money += 1

    args.state.hint_visibility -= 1
    args.state.hint_visibility = args.state.hint_visibility.clamp(0, 255)
    
    play_sound "sounds/nokia_soundpack_@trix/blip4.wav"
    # Record the timestamp of this click
    args.state.manual_clicks << args.state.tick_count
  end
end

def process_building_select(args)
  building = visible_buildings[args.state.selection.idx]
  
  if building
    confirm(args, "Buy #{building.name} for $#{building.cost}?") do |result|
      if result && args.state.money >= building.cost
        play_sound "sounds/nokia_soundpack_@trix/good3.wav"

        args.state.money -= building.cost
        building[:count] += 1
        args.state.income_per_second += building.income
        
        # Update the cost for the next purchase
        building.cost = calculate_cost(
          building.base_cost, 
          building[:count]
        )
        save_game(args)
      else
        play_sound "sounds/nokia_soundpack_@trix/blip8.wav"
      end
    end
  end
end

def process_passive_income(args)
  # Add income every frame (60 fps)
  args.state.money += args.state.income_per_second / 60.0
  
  # Calculate manual income rate by counting clicks in the last second (60 ticks)
  args.state.manual_clicks.reject! { |timestamp| timestamp < args.state.tick_count - 60 }
  args.state.manual_income_rate = args.state.manual_clicks.length
end

def process_confirm(args)
  args.state.confirm_result = args.state.confirm_selection == 0
  args.state.confirm_open = false
  args.state.confirm_block.call(args.state.confirm_result) if args.state.confirm_block
  args.state.confirm_block = nil
end

def confirm(args, message, &block)
  args.state.confirm_open = true
  args.state.confirm_message = message
  args.state.confirm_selection = 0
  args.state.confirm_block = block
end

def split_text(t, max_w) 
  lines = []
  text = []
  t.split(" ").each do |word|
    ww,hh = $gtk.calcstringbox((text + [word]).join(" "), size_px: 6, font: "tiny.ttf")
    if ww >= max_w
      lines << text.join(" ")
      text = [word]
    else 
      text << word
    end
  end

  lines << text.join(" ")
  lines
end

def render_confirm(args)
  nokia.primitives << {
    x: 10,
    y: 10,
    w: NOKIA_WIDTH - 20,
    h: NOKIA_HEIGHT - 20,
    **PALLETTE[:primary],
    primitive_marker: :solid
  }
  
  nokia.primitives << {
    x: 11,
    y: 11,
    w: NOKIA_WIDTH - 22,
    h: NOKIA_HEIGHT - 22,
    **PALLETTE[:secondary],
    primitive_marker: :solid
  }
  
  y_offset = NOKIA_HEIGHT - 12
  
  if args.state.confirm_message
    lines = split_text(args.state.confirm_message, NOKIA_WIDTH - 22)
    lines.each do |line|
      nokia.primitives << {
        x: NOKIA_WIDTH / 2 - (NOKIA_WIDTH - 22) / 2 + 2,
        y: y_offset,
        text: line,
        **PALLETTE[:primary],
        size_px: 6,
        font: "tiny.ttf",
        primitive_marker: :label
      }
      y_offset -= 7
    end
  end
  
  nokia.primitives << {
    x: NOKIA_WIDTH / 2 - 15,
    y: 12,
    w: 10,
    h: 10,
    **PALLETTE[args.state.confirm_selection == 0 ? :primary : :secondary],
    primitive_marker: :solid
  }
  
  nokia.primitives << {
    x: NOKIA_WIDTH / 2 - 15 + 5,
    y: 12 + 5,
    text: "Y",
    **PALLETTE[args.state.confirm_selection == 0 ? :secondary : :primary],
    alignment_enum: 1, # Center aligned
    vertical_alignment_enum: 1, # Center aligned
    size_px: 6,
    font: "tiny.ttf",
    primitive_marker: :label
  }
  
  nokia.primitives << {
    x: NOKIA_WIDTH / 2 + 5,
    y: 12,
    w: 10,
    h: 10,
    **PALLETTE[args.state.confirm_selection == 1 ? :primary : :secondary],
    primitive_marker: :solid
  }
  
  nokia.primitives << {
    x: NOKIA_WIDTH / 2 + 5 + 5,
    y: 12 + 5,
    text: "N",
    **PALLETTE[args.state.confirm_selection == 1 ? :secondary : :primary],
    alignment_enum: 1, # Center aligned
    vertical_alignment_enum: 1, # Center aligned
    size_px: 6,
    font: "tiny.ttf",
    primitive_marker: :label
  }
end

def render_buildings(args) 
  # Calculate grid layout dimensions
  columns = 3
  rows = (args.state.buildings.length / columns.to_f).ceil
  
  cell_width = (NOKIA_WIDTH - 4) / columns
  cell_height = (NOKIA_HEIGHT - STATUS_BAR_H - 4) / rows

  visible_buildings.each_with_index do |building, idx|
    row = (idx / columns).to_i
    col = idx % columns
    
    # Calculate position
    x = col * cell_width + 2
    y = NOKIA_HEIGHT - STATUS_BAR_H - (row + 1) * cell_height - 2

    if idx == args.state.selection.idx
      nokia.primitives << {
        x: x,
        y: y,
        w: cell_width,
        h: cell_height,
        **PALLETTE[:primary],
        primitive_marker: :border
      }
    end

    nokia.primitives << {
      x: x + 2,
      y: y,
      **PALLETTE[:primary],
      text: building.short_name,
      size_px: 6,
      font: "tiny.ttf",
      alignment_enum: 0,
      vertical_alignment_enum: 0,
      primitive_marker: :label
    }
    
    nokia.primitives << {
      x: x + cell_width - 2,
      y: y + 4,
      text: building[:count],
      **PALLETTE[:primary],
      alignment_enum: 2, # Right aligned
      vertical_alignment_enum: 0, # Top aligned
      size_px: 6,
      font: "tiny.ttf",
      primtiive_marker: :label
    }
  end
  
  nokia.primitives << {
    x: 2,
    y: 2,
    w: NOKIA_WIDTH - 4,
    h: 10,
    **PALLETTE[:primary], a: args.state.hint_visibility == 0 ? 0 : 255,
    primitive_marker: :border
  }
  
  nokia.primitives << {
    x: NOKIA_WIDTH / 2,
    y: 7,
    text: "GENERATE INCOME (G)",
    **PALLETTE[:primary], a: args.state.hint_visibility == 0 ? 0 : 255,
    alignment_enum: 1, # Center aligned
    vertical_alignment_enum: 1, # Center aligned
    size_px: 6,
    font: "tiny.ttf",
    primitive_marker: :label
  }
end

def render_status_bar(args)
  nokia.primitives << {
    x: 0,
    y: NOKIA_HEIGHT - STATUS_BAR_H,
    w: NOKIA_WIDTH,
    h: STATUS_BAR_H,
    **PALLETTE[:primary],
    primitive_marker: :solid
  }
  
  money_text = args.state.money.to_i
  if money_text >= 1_000_000_000
    money_text = "%.2E" % money_text
  end
  nokia.primitives << {
    x: 2,
    y: NOKIA_HEIGHT - 2,
    text: "$#{money_text}",
    **PALLETTE[:secondary],
    alignment_enum: 0, # Left aligned
    size_px: 6,
    font: "tiny.ttf",
    primtiive_marker: :label
  }
  
  total_income = args.state.income_per_second + args.state.manual_income_rate
  
  nokia.primitives << {
    x: NOKIA_WIDTH - 2,
    y: NOKIA_HEIGHT - 2,
    text: "+$#{total_income.to_i}/s",
    **PALLETTE[:secondary],
    alignment_enum: 2, # Right aligned
    size_px: 6,
    font: "tiny.ttf",
    primtiive_marker: :label
  }
end