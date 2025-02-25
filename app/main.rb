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
MACHINE_SIZE = 16

MILL = {
  speed: 0,
  production: 0,
  level: 0,
  purchased: false,
  turn_state: 0,
  upgrade_cost: 50,
  max_grain: 100,
  grain_amount: 0,
  production_counter: 0
}

def boot(args)
  args.state = {
    level: 1,
    money: 50,
    time: 0,
    view: :room,
    confirm_open: false,
    confirm_selection: 0,
    mill_selection: 0,
    grind_selection: 0,
    selection: {
      x: 0,
      y: 0
    },
    mills: [
      [MILL.dup, MILL.dup],
      [MILL.dup, MILL.dup]
    ]
  }
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

  process_mill_production(args) if args.state.view != :grind

  if args.state.confirm_open
    handle_confirm_input(args)
  elsif args.state.view == :room
    handle_room_input(args)
  elsif args.state.view == :mill
    handle_mill_input(args)
  elsif args.state.view == :grind
    handle_grind_input(args)
  end

  if args.state.view == :room
    render_room_status_bar(args)
    render_room(args)
  elsif args.state.view == :mill
    render_mill_status_bar(args)
    render_mill(args)
  elsif args.state.view == :grind
    render_mill_status_bar(args)
    render_grind_screen(args)
  end 

  if args.state.confirm_open 
    render_confirm(args)
  end

  args.outputs.sprites << {
    x: WIDTH / 2,
    y: HEIGHT / 2,
    w: ZOOMED_WIDTH,
    h: ZOOMED_HEIGHT,
    anchor_x: 0.5,
    anchor_y: 0.5,
    path: :nokia,
  }
end

def nokia 
  $args.outputs[:nokia]
end

def calculate_cost(base_cost, level, multiplier = 1.15)
  (base_cost * (multiplier ** level)).floor
end

def handle_confirm_input(args)
  if args.inputs.keyboard.key_down.left
    args.state.confirm_selection = (args.state.confirm_selection - 1).clamp(0, 1)
  elsif args.inputs.keyboard.key_down.right
    args.state.confirm_selection = (args.state.confirm_selection + 1).clamp(0, 1)
  elsif args.inputs.keyboard.key_down.space
    process_confirm(args)
  end
end

def handle_mill_input(args)
  if args.inputs.keyboard.key_down.left
    args.state.mill_selection = (args.state.mill_selection - 1).clamp(0, 2)
  elsif args.inputs.keyboard.key_down.right
    args.state.mill_selection = (args.state.mill_selection + 1).clamp(0, 2)
  elsif args.inputs.keyboard.key_down.space
    process_mill_button_select(args)
  end
end

def handle_grind_input(args)
  mill = args.state.selected_mill
  
  if args.inputs.keyboard.key_down.space
    if args.state.grind_selection == 1
      if mill.level == 0
        # For non-upgraded mills, space turns the wheel manually
        if !mill.grain_amount || mill.grain_amount < mill.max_grain
          # Add grain
          mill.grain_amount ||= 0
          mill.grain_amount += 1
          mill.grain_amount = [mill.grain_amount, mill.max_grain].min
        
        # Animate mill turning
        mill.turn_state = (mill.turn_state + 1) % 4
      end
      else
        # For upgraded mills, just return to mill view
        args.state.view = :mill
      end
    elsif args.state.grind_selection == 0
      args.state.view = :mill
    end
  elsif args.inputs.keyboard.key_down.right
    args.state.grind_selection = (args.state.grind_selection + 1).clamp(0, 1)
  elsif args.inputs.keyboard.key_down.left
    args.state.grind_selection = (args.state.grind_selection - 1).clamp(0, 1)
  end
  
  # Return to mill view if the mill is full
  if mill.grain_amount && mill.grain_amount >= mill.max_grain
    args.state.view = :mill
  end
end

def process_mill_button_select(args)
  if args.state.mill_selection == 0
    cost = calculate_cost(args.state.selected_mill.upgrade_cost, args.state.selected_mill.level)
    if args.state.money >= cost
      args.state.money -= cost
      args.state.selected_mill.level += 1
    end 
  elsif args.state.mill_selection == 1
    if args.state.selected_mill.grain_amount && args.state.selected_mill.grain_amount >= args.state.selected_mill.max_grain
      # Collect the grain (sell it for money)
      grain_value = args.state.selected_mill.grain_amount * (1 + args.state.selected_mill.level * 0.1)
      args.state.money += grain_value.to_i
      args.state.selected_mill.grain_amount = 0
    else
      # Only go to grinding view for level 0 mills
      if args.state.selected_mill.level == 0
        args.state.view = :grind
      end
    end
  elsif args.state.mill_selection == 2
    args.state.selected_mill = nil
    args.state.view = :room
  end
end

def process_mill_production(args)
  args.state.mills.flatten.each do |mill|
    # Skip mills that are not purchased or not upgraded (level 0)
    next unless mill && mill.purchased && mill.level > 0
    
    # Skip mills that are already full
    next if mill.grain_amount && mill.grain_amount >= mill.max_grain
    
    # Initialize production_counter if it doesn't exist
    mill.production_counter ||= 0
    
    # Calculate production speed based on mill level
    # Lower level = slower production
    production_speed = 10 - [mill.level * 2, 9].min # Range from 10 (slowest) to 1 (fastest)
    
    # Increment counter
    mill.production_counter += 1
    
    # Only produce grain when counter hits the production speed
    if mill.production_counter >= production_speed
      mill.production_counter = 0
      
      # Add grain based on level
      mill.grain_amount ||= 0
      mill.grain_amount += 1
      mill.grain_amount = [mill.grain_amount, mill.max_grain].min
      
      # Update turn state for animation
      mill.turn_state = (mill.turn_state + 1) % 4
    end
  end
end

def process_confirm(args)
  if args.state.confirm_selection == 0
    args.state.confirm_block.call(true)
  else
    args.state.confirm_block.call(false)
  end
  args.state.confirm_open = false
  args.state.confirm_block = nil
  args.state.confirm_selection = 0
end

def handle_room_input(args)
  if args.inputs.keyboard.key_down.left
    args.state.selection.x = (args.state.selection.x - 1).clamp(0, 1)
  elsif args.inputs.keyboard.key_down.right
    args.state.selection.x = (args.state.selection.x + 1).clamp(0, 1)
  elsif args.inputs.keyboard.key_down.up
    args.state.selection.y = (args.state.selection.y - 1).clamp(0, 1)
  elsif args.inputs.keyboard.key_down.down
    args.state.selection.y = (args.state.selection.y + 1).clamp(0, 1)
  elsif args.inputs.keyboard.key_down.space
    process_mill_select(args)
  end
end

def process_mill_select(args)
  mill = args.state.mills[args.state.selection.y][args.state.selection.x]
  if mill.purchased
    args.state.selected_mill = mill
    args.state.view = :mill
  else
    confirm(args, "Do you want to buy a mill for $#{mill.upgrade_cost}?") do |result|
      if result && args.state.money >= mill.upgrade_cost
        mill.purchased = true
        args.state.money -= mill.upgrade_cost
        args.state.mills.flatten.each do |m|
          next if m == mill
          m.upgrade_cost += 50
        end
      end
    end
  end
end

def confirm(args, message, &block)
  args.state.confirm_message = message
  args.state.confirm_block = block
  args.state.confirm_open = true
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
    x: 4, y: 4,
    w: NOKIA_WIDTH - 8,
    h: NOKIA_HEIGHT - 8,
    **PALLETTE[:secondary],
    primitive_marker: :solid
  }

  nokia.primitives << { 
    x: 4, y: 4,
    w: NOKIA_WIDTH - 8,
    h: NOKIA_HEIGHT - 8,
    **PALLETTE[:primary],
    primitive_marker: :border
  }

  split_text(args.state.confirm_message, NOKIA_WIDTH - 8).each_with_index do |line, y|
    nokia.primitives << {
      x: 6, y: (NOKIA_HEIGHT - 8) - y * 6,
      text: line,
      size_px: 6,
      vertical_alignment_enum: 1,
      font: "tiny.ttf",
      **PALLETTE[:primary],
      primitive_marker: :label
    }
  end

  ["Okay", "Cancel"].each_with_index do |text, x|
    selected = x == args.state.confirm_selection
    text_color = selected ? PALLETTE[:secondary] : PALLETTE[:primary]
    background_color = selected ? PALLETTE[:primary] : PALLETTE[:secondary]
    
    w, h = $gtk.calcstringbox(text, size_px: 6, font: "tiny.ttf")

    nokia.primitives << {
      x: x * 24 + 17, y: 12,
      text: text,
      size_px: 6,
      w: w + 3,
      h: h + 3,
      **background_color,
      primitive_marker: :solid
    }
    
    nokia.primitives << {
      x: x * 24 + 17, y: 12,
      text: text,
      size_px: 6,
      w: w + 3,
      h: h + 3,
      **PALLETTE[:primary],
      primitive_marker: :border
    }

    nokia.primitives << {
      x: x * 24 + 19, y: 14,
      w: 16, h: 16,
      text: text,
      size_px: 6,
      vertical_alignment_enum: 0,
      font: "tiny.ttf",
      **text_color,
      primitive_marker: :label
    }
  end
end

def render_room(args)
  w_raw = (NOKIA_WIDTH - 4) / args.state.mills.length
  h_raw = (NOKIA_HEIGHT - 20) / args.state.mills.first.length

  width  = w_raw.to_i
  height = h_raw.to_i

  hovered_mill = args.state.mills[args.state.selection.y][args.state.selection.x]
  nokia.primitives << {
    x: args.state.selection.x * width + 2,
    y: (args.state.mills.first.length - args.state.selection.y - 1) * height + 4,
    w: width, h: height,
    **PALLETTE[:primary],
    primitive_marker: :border
  }

  args.state.mills.each_with_index do |row, x|
    row.each_with_index do |mill, y|
      if mill.purchased 
        nokia.primitives << {
          x: x * width + 2,
          y: (args.state.mills.first.length - y - 1) * height + 4,
          w: width,
          h: height,
          **PALLETTE[:primary],
          primitive_marker: :solid
        }
        
        render_mill_90(
          x * width + 2 + width / 2, 
          (args.state.mills.first.length - y - 1) * height + 4 + height / 2
        )
        
        if mill.grain_amount && mill.grain_amount > 0
          fill_percentage = mill.grain_amount.to_f / mill.max_grain
          fill_height = (height * fill_percentage).to_i.clamp(1, height - 2)
          
          nokia.primitives << {
            x: x * width + 2 + width - 4,
            y: (args.state.mills.first.length - y - 1) * height + 4 + 1,
            w: 3,
            h: height - 2,
            **PALLETTE[:secondary],
            primitive_marker: :border
          }
          
          nokia.primitives << {
            x: x * width + 2 + width - 4,
            y: (args.state.mills.first.length - y - 1) * height + 4 + 1,
            w: 3,
            h: fill_height,
            **PALLETTE[:secondary],
            primitive_marker: :solid
          }
          
          if mill.grain_amount >= mill.max_grain
            nokia.primitives << {
              x: x * width + 2 + 2,
              y: (args.state.mills.first.length - y - 1) * height + 4 + height - 4,
              w: 4,
              h: 3,
              **PALLETTE[:secondary],
              primitive_marker: :solid
            }
          end
        end
      else
        nokia.primitives << {
          x: x * width + 2 + (width / 2) - 2,
          y: (args.state.mills.first.length - y - 1) * height + 4 + (height / 2) - 2,
          w: 4,
          h: 4,
          **PALLETTE[:primary],
          primitive_marker: :solid
        }
      end
    end
  end
end

def render_mill_90(x_pos, y_pos)
  nokia.primitives << {
    x: x_pos,
    x2: x_pos,
    y: y_pos - 2,
    y2: y_pos + 2,
    **PALLETTE[:secondary],
    primitive_marker: :line
  }

  nokia.primitives << {
    x: x_pos + 2,
    x2: x_pos - 2,
    y: y_pos,
    y2: y_pos,
    **PALLETTE[:secondary],
    primitive_marker: :line
  }
end

def render_mill_45(x_pos, y_pos)
  nokia.primitives << {
    x: x_pos,
    y: y_pos,
    w: 1,
    h: 1,
    **PALLETTE[:secondary],
    primitive_marker: :solid
  }

  nokia.primitives << {
    x: x_pos - 1,
    y: y_pos - 1,
    w: 1,
    h: 1,
    **PALLETTE[:secondary],
    primitive_marker: :solid
  }
  nokia.primitives << {
    x: x_pos - 2,
    y: y_pos - 2,
    w: 1,
    h: 1,
    **PALLETTE[:secondary],
    primitive_marker: :solid
  }
  nokia.primitives << {
    x: x_pos + 1,
    y: y_pos + 1,
    w: 1,
    h: 1,
    **PALLETTE[:secondary],
    primitive_marker: :solid
  }
  nokia.primitives << {
    x: x_pos + 2,
    y: y_pos + 2,
    w: 1,
    h: 1,
    **PALLETTE[:secondary],
    primitive_marker: :solid
  }

  nokia.primitives << {
    x: x_pos - 1,
    y: y_pos + 1,
    w: 1,
    h: 1,
    **PALLETTE[:secondary],
    primitive_marker: :solid
  }
  nokia.primitives << {
    x: x_pos - 2,
    y: y_pos + 2,
    w: 1,
    h: 1,
    **PALLETTE[:secondary],
    primitive_marker: :solid
  }
  nokia.primitives << {
    x: x_pos + 1,
    y: y_pos - 1,
    w: 1,
    h: 1,
    **PALLETTE[:secondary],
    primitive_marker: :solid
  }
  nokia.primitives << {
    x: x_pos + 2,
    y: y_pos - 2,
    w: 1,
    h: 1,
    **PALLETTE[:secondary],
    primitive_marker: :solid
  }
end

def render_mill(args)
  x_pos = 2
  y_pos = 18
  mill = args.state.selected_mill

  nokia.primitives << { 
    x: x_pos, y: y_pos,
    w: 16, h: 16,
    **PALLETTE[:primary],
    primitive_marker: :solid
  }

  nokia.primitives << { 
    x: x_pos + 18, y: y_pos,
    w: 62, h: 16,
    **PALLETTE[:primary],
    primitive_marker: :solid
  }

  # Calculate production speed based on mill level for display
  production_speed = 10 - [mill.level * 2, 9].min
  speed_text = production_speed == 1 ? "Fast" : (production_speed >= 8 ? "Slow" : "Medium")
  
  if mill.level > 0
    nokia.primitives << {
      x: x_pos + 20, y: y_pos + 16,
      **PALLETTE[:secondary],
      text: "Auto Prod: #{1}/grain",
      size_px: 6,
      font: "tiny.ttf",
      primitive_marker: :label
    }
  else
    nokia.primitives << {
      x: x_pos + 20, y: y_pos + 16,
      **PALLETTE[:secondary],
      text: "Manual Grinding",
      size_px: 6,
      font: "tiny.ttf",
      primitive_marker: :label
    }
  end

  nokia.primitives << {
    x: x_pos + 20, y: y_pos + 11,
    **PALLETTE[:secondary],
    text: "Speed: #{speed_text}",
    size_px: 6,
    font: "tiny.ttf",
    primitive_marker: :label
  }

  nokia.primitives << {
    x: x_pos + 20, y: y_pos + 6,
    **PALLETTE[:secondary],
    text: "Grain: #{mill.grain_amount || 0}/#{mill.max_grain}",
    size_px: 6,
    font: "tiny.ttf",
    primitive_marker: :label
  }

  nokia.primitives << {
    x: x_pos, y: 2,
    w: NOKIA_WIDTH - 4,
    h: 14,
    **PALLETTE[:primary],
    primitive_marker: :solid
  }

  nokia.primitives << {
    x: x_pos + 4, y: 5,
    w: 20,
    h: 8,
    **PALLETTE[args.state.mill_selection == 0 ? :primary : :secondary],
    primitive_marker: :solid
  }

  nokia.primitives << {
    x: x_pos + 4, y: 5,
    w: 20,
    h: 8,
    **PALLETTE[:secondary],
    primitive_marker: :border
  }

  nokia.primitives << { 
    x: x_pos + 7, y: 12,
    text: "Upg.",
    size_px: 6,
    font: "tiny.ttf",
    primitive_marker: :label,
    **PALLETTE[args.state.mill_selection == 0 ? :secondary : :primary]
  }

  button_text = (mill.grain_amount && mill.grain_amount >= mill.max_grain) ? "Coll." : "Grind"
  
  nokia.primitives << {
    x: x_pos + 30, y: 5,
    w: 20,
    h: 8,
    **PALLETTE[args.state.mill_selection == 1 ? :primary : :secondary],
    primitive_marker: :solid
  }

  nokia.primitives << {
    x: x_pos + 30, y: 5,
    w: 20,
    h: 8,
    **PALLETTE[:secondary],
    primitive_marker: :border
  }

  nokia.primitives << { 
    x: x_pos + 32, y: 12,
    text: button_text,
    size_px: 6,
    font: "tiny.ttf",
    primitive_marker: :label,
    **PALLETTE[args.state.mill_selection == 1 ? :secondary : :primary]
  }

  nokia.primitives << {
  x: x_pos + 56, y: 5,
    w: 20,
    h: 8,
    **PALLETTE[args.state.mill_selection == 2 ? :primary : :secondary],
    primitive_marker: :solid
  }

  nokia.primitives << {
    x: x_pos + 56, y: 5,
    w: 20,
    h: 8,
    **PALLETTE[:secondary],
    primitive_marker: :border
  }

  nokia.primitives << { 
    x: x_pos + 58, y: 12,
    text: "Back",
    size_px: 6,
    font: "tiny.ttf",
    primitive_marker: :label,
    **PALLETTE[args.state.mill_selection == 2 ? :secondary : :primary]
  }
  
  # Render the mill in the center of the box
  if args.state.selected_mill.turn_state == 0
    render_mill_90(x_pos + 8, y_pos + 8)
  elsif args.state.selected_mill.turn_state == 1
    render_mill_45(x_pos + 8, y_pos + 8)
  elsif args.state.selected_mill.turn_state == 2
    # Render horizontally
    nokia.primitives << {
      x: x_pos + 6,
      x2: x_pos + 10,
      y: y_pos + 8,
      y2: y_pos + 8,
      **PALLETTE[:secondary],
      primitive_marker: :line
    }
  else
    # Render at -45 degrees
    nokia.primitives << {
      x: x_pos + 8,
      y: y_pos + 8,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
    nokia.primitives << {
      x: x_pos + 9,
      y: y_pos + 7,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
    nokia.primitives << {
      x: x_pos + 10,
      y: y_pos + 6,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
    nokia.primitives << {
      x: x_pos + 7,
      y: y_pos + 9,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
    nokia.primitives << {
      x: x_pos + 6,
      y: y_pos + 10,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
    nokia.primitives << {
      x: x_pos + 7,
      y: y_pos + 7,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
    nokia.primitives << {
      x: x_pos + 6,
      y: y_pos + 6,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
    nokia.primitives << {
      x: x_pos + 9,
      y: y_pos + 9,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
    nokia.primitives << {
      x: x_pos + 10,
      y: y_pos + 10,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
  end
end

def render_grind_screen(args)
  # Show animation of mill spinning and grinding grain
  x_pos = 2
  y_pos = 18
  mill = args.state.selected_mill
  
  # Show the mill in the center
  nokia.primitives << { 
    x: x_pos, y: y_pos,
    w: NOKIA_WIDTH - 4, h: 15,
    **PALLETTE[:primary],
    primitive_marker: :solid
  }
  
  mill_x = NOKIA_WIDTH / 2
  mill_y = y_pos + 8
  
  if args.state.selected_mill.turn_state == 0
    render_mill_90(mill_x, mill_y)
  elsif args.state.selected_mill.turn_state == 1
    render_mill_45(mill_x, mill_y)
  elsif args.state.selected_mill.turn_state == 2
    nokia.primitives << {
      x: mill_x - 2,
      x2: mill_x + 2,
      y: mill_y,
      y2: mill_y,
      **PALLETTE[:secondary],
      primitive_marker: :line
    }
  else
    nokia.primitives << {
      x: mill_x,
      y: mill_y,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
    nokia.primitives << {
      x: mill_x + 1,
      y: mill_y - 1,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
    nokia.primitives << {
      x: mill_x + 2,
      y: mill_y - 2,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
    nokia.primitives << {
      x: mill_x - 1,
      y: mill_y + 1,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
    nokia.primitives << {
      x: mill_x - 2,
      y: mill_y + 2,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
    nokia.primitives << {
      x: mill_x - 1,
      y: mill_y - 1,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
    nokia.primitives << {
      x: mill_x - 2,
      y: mill_y - 2,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
    nokia.primitives << {
      x: mill_x + 1,
      y: mill_y + 1,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
    nokia.primitives << {
      x: mill_x + 2,
      y: mill_y + 2,
      w: 1,
      h: 1,
      **PALLETTE[:secondary],
      primitive_marker: :solid
    }
  end

  nokia.primitives << {
    x: x_pos, y: 2,
    w: NOKIA_WIDTH - 4,
    h: 14,
    **PALLETTE[:primary],
    primitive_marker: :solid
  }
  
  # Back button  
  nokia.primitives << {
    x: 12, y: 5,
    w: 20, h: 8,
    **PALLETTE[args.state.grind_selection == 0 ? :secondary : :primary],
    primitive_marker: :solid
  }

  nokia.primitives << {
    x: 12, y: 5,
    w: 20,
    h: 8,
    **PALLETTE[:secondary],
    primitive_marker: :border
  }
  
  nokia.primitives << { 
    x: 14, y: 12,
    text: "Back",
    size_px: 6,
    font: "tiny.ttf",
    primitive_marker: :label,
    **PALLETTE[args.state.grind_selection == 0 ? :primary : :secondary]
  }

    
  # Grind button
  nokia.primitives << {
    x: 50, y: 5,
    w: 20, h: 8,
    **PALLETTE[args.state.grind_selection == 1 ? :secondary : :primary],
    primitive_marker: :solid
  }


  nokia.primitives << {
    x: 50, y: 5,
    w: 20,
    h: 8,
    **PALLETTE[:secondary],
    primitive_marker: :border
  }
  
  nokia.primitives << { 
    x: 52, y: 12,
    text: "Grind",
    size_px: 6,
    font: "tiny.ttf",
    primitive_marker: :label,
    **PALLETTE[args.state.grind_selection == 1 ? :primary : :secondary],
  }
end

# def render_info_bar(args)
#   nokia.solids << {
#     x: 0, y: 0,
#     w: NOKIA_WIDTH,
#     h: 4,
#     **PALLETTE[:primary]
#   }

#   text = "Purchase Mill $100"

#   w, h = $gtk.calcstringbox(text, size_px: 6, font: "tiny.ttf")
#   nokia.labels << {
#     x: 1, y: h / 2,
#     w: NOKIA_WIDTH,
#     h: 4,
#     text: text,
#     size_px: 6,
#     vertical_alignment_enum: 1,
#     font: "tiny.ttf",
#     **PALLETTE[:secondary]
#   }
# end

def render_room_status_bar(args)
  nokia.primitives << { 
    x: 0, y: NOKIA_HEIGHT - STATUS_BAR_H,
    w: NOKIA_WIDTH,
    h: STATUS_BAR_H,
    **PALLETTE[:primary],
    primitive_marker: :solid
  }

  text = "$#{args.state.money} L:#{args.state.level} T:#{args.state.time}"

  w, h = $gtk.calcstringbox(text, size_px: 6, font: "tiny.ttf")
  nokia.primitives << {
    x: 1, y: NOKIA_HEIGHT - h,
    w: NOKIA_WIDTH,
    h: STATUS_BAR_H,
    text: text,
    size_px: 6,
    vertical_alignment_enum: 1,
    font: "tiny.ttf",
    **PALLETTE[:secondary],
    primitive_marker: :label
  }
end 

def render_mill_status_bar(args)
  nokia.primitives << { 
    x: 0, y: NOKIA_HEIGHT - STATUS_BAR_H,
    w: NOKIA_WIDTH,
    h: STATUS_BAR_H,
    **PALLETTE[:primary],
    primitive_marker: :solid
  }

  text = "Mill lvl #{args.state.selected_mill.level}"
  if args.state.view == :grind 
    text += " Grain #{args.state.selected_mill.grain_amount}/#{args.state.selected_mill.max_grain}"
  else
    text += " (Upg. $#{calculate_cost(args.state.selected_mill.upgrade_cost, args.state.selected_mill.level)})" 
  end

  w, h = $gtk.calcstringbox(text, size_px: 6, font: "tiny.ttf")
  nokia.primitives << {
    x: 1, y: NOKIA_HEIGHT - h,
    w: NOKIA_WIDTH,
    h: STATUS_BAR_H,
    text: text,
    size_px: 6,
    vertical_alignment_enum: 1,
    font: "tiny.ttf",
    **PALLETTE[:secondary],
    primitive_marker: :label
  }
end