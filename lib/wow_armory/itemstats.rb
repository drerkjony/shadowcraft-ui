module WowArmory
  class Itemstats
    unloadable

    @random_suffix_csv = nil
    @item_enchants = nil
    @rand_prop_points = nil
    @item_data = nil
    @item_damage_one_hand = nil
    @item_bonus_trees = nil
    @item_bonus_data = nil

    STAT_LOOKUP = {
      49=>:mastery, 
      38=>:attack_power, 
      5=>:intellect,
      44=>:armor_penetration,
      33=>:hit_avoidance,
      6=>:spirit,
      12=>:defense,
      45=>:power,
      34=>:critical_strike_avoidance,
      1=>:health,
      7=>:stamina,
      3=>:agility,
      2=>:mana,
      13=>:dodge,
      46=>:health_every_5_seconds,
      57=>:pvp_power,
      35=>:pvp_resilience,
      41=>:damage_done,
      14=>:parry,
      36=>:haste,
      47=>:penetration,
      31=>:hit,
      42=>:healing_done,
      4=>:strength, 
      37=>:expertise,
      15=>:shield_block,
      48=>:block_value,
      32=>:crit,
      43=>:mana_every_5_seconds,
      71=>:agility,
      72=>:agility,
      73=>:agility,
      40=>:versatility,
      59=>:multistrike,
      58=>:amplify,
      50=>:bonus_armor,
      63=>:avoidance,
      67=>:versatility
    }

    WOWHEAD_MAP = {
      "hitrtng" => "hit",
      "hastertng" => "haste",
      "critstrkrtng" => "crit",
      "mastrtng" => "mastery",
      "exprtng" => "expertise",
      "agi" => "agility",
      "sta" => "stamina",
      "pvppower" => "pvp_power",
      "resirtng" => "pvp_resilience",
      "multistrike" => "multistrike",
      "versatility" => "versatility"
    }

    BONUS_ACTIONS = {
       1 => :ADJUST_ITEM_LEVEL,
       2 => :MODIFY_STATS,
       3 => :CHANGE_ITEM_QUALITY,
       4 => :ADD_ITEM_TITLES,
       5 => :APPEND_WORDS_TO_ITEM_NAME,
       6 => :ADD_SOCKETS,
       7 => :ADJUST_ITEM_APPEARANCE_ID,
       8 => :ADJUST_EQUIP_LEVEL,
       9 => :UNKNOWN_1,
      10 => :UNKNOWN_2,
    }

    ITEM_SOCKET_COST = 8.0 # lvl 100 = 30.

    ACCESSORS = :stats, :name, :dps, :random_suffix, :upgrade_level, :bonus_trees
    attr_accessor *ACCESSORS
    def initialize(properties, random_suffix = nil, upgrade_level = nil, bonus_trees = [])
      self.stats = {}
      @properties = properties
      self.random_suffix = random_suffix
      self.random_suffix = nil if self.random_suffix == 0
      self.upgrade_level = upgrade_level
      self.upgrade_level = nil if self.upgrade_level == 0
      self.name = @properties[:name]
      self.bonus_trees = bonus_trees

      populate_stats
    end

    def as_json(options = {})
      {}.tap do |r|
        ACCESSORS.map {|key| r[key] = self.send(key) }
      end
    end

    private

    def populate_item_upgrade_level_with_random_suffix
      row = random_suffixes[random_suffix.abs.to_s]
      if row.nil?
        raise StandardError.new "no suffix data found in client db files for random_suffix id #{random_suffix.abs}"
      end
      base = rand_prop_points[@properties[:ilevel].to_s]

      4.times do |i|
        enchantid = row[3+i]
        multiplier = row[8+i].to_f / 10000.0
        basevalue = base[1+quality_index(@properties[:quality])*5+slot_index(@properties[:equip_location])]
        if enchantid != '0'
          stat = item_enchants[enchantid][14].to_i
          self.stats[STAT_LOOKUP[stat]] = (multiplier * basevalue.to_i).to_i
        end
      end
    end

    def populate_item_upgrade_level
      row = item_data[@properties[:id].to_s]
      if row.nil?
        raise StandardError.new "no item data found in client db files for id #{@properties[:id]}"
      end
      base = rand_prop_points[@properties[:ilevel].to_s]

      self.stats = {}
      # wod offset
      offset = 0
      10.times do |i|
        break if row[16+offset+i] == '-1'
        enchantid = row[16+offset+i] # more or less stat-id
        multiplier = row[36+offset+i].to_f
        socket_mult  = row[46+offset+i].to_f
        basevalue = base[1+quality_index(@properties[:quality])*5+slot_index(@properties[:equip_location])]
        if enchantid != '0'
          stat = enchantid.to_i
          
          value = ((multiplier/10000.0) * basevalue.to_f).round - (socket_mult * ITEM_SOCKET_COST).round
          self.stats[STAT_LOOKUP[stat]] = value
          #puts STAT_LOOKUP[stat]
          #puts self.stats[STAT_LOOKUP[stat]]
        end
      end
    end

    def populate_item_upgrade_level_not_accurate   
      ori_base = rand_prop_points[@ori_ilevel.to_s]
      base = rand_prop_points[@properties[:ilevel].to_s]
      ori_basevalue = ori_base[1+quality_index(@properties[:quality])*5+slot_index(@properties[:equip_location])]
      basevalue = base[1+quality_index(@properties[:quality])*5+slot_index(@properties[:equip_location])]
      self.stats.each do |stat, val|
        new_val = (val * basevalue.to_f) / ori_basevalue.to_f
        self.stats[stat] = new_val.round
      end
    end

    def populate_random_suffix_item
      row = random_suffixes[random_suffix.abs.to_s]
      base = rand_prop_points[@properties[:ilevel].to_s]

      populate_item_upgrade_level
      4.times do |i|
        enchantid = row[3+i]
        multiplier = row[8+i].to_f / 10000.0
        basevalue = base[1+quality_index(@properties[:quality])*5+slot_index(@properties[:equip_location])]
        if enchantid != "0"
          stat = item_enchants[enchantid][14].to_i
          self.stats[STAT_LOOKUP[stat]] = (multiplier * basevalue.to_i).to_i # looks like round is wrong and floor is correct
        end
      end
    end

    def random_suffixes
      @@random_suffix_csv ||= Hash.new.tap do |hash|
        FasterCSV.foreach(File.join(File.dirname(__FILE__), "data", "ItemRandomSuffix.dbc.csv")) do |row|
          hash[row[0].to_s] = row
        end
      end
    end

    def item_enchants
      @@item_enchants ||= Hash.new.tap do |hash|
        FasterCSV.foreach(File.join(File.dirname(__FILE__), "data", "WoD_SpellItemEnchantments.csv")) do |row|
          hash[row[0].to_s] = row
        end
      end
    end

    def rand_prop_points
      @@rand_prop_points ||= Hash.new.tap do |hash|
        FasterCSV.foreach(File.join(File.dirname(__FILE__), "data", "WoD_RandPropPoints.dbc.csv")) do |row|
          hash[row[0].to_s] = row
        end
      end
    end

    def item_data
      @@item_data ||= Hash.new.tap do |hash|
        FasterCSV.foreach(File.join(File.dirname(__FILE__), "data", "WoD_item_data.csv")) do |row|
          hash[row[0].to_s] = row
        end
      end
    end

    def item_damage_one_hand
      @@item_damage_one_hand ||= Hash.new.tap do |hash|
        FasterCSV.foreach(File.join(File.dirname(__FILE__), "data", "WoD_ItemDamageOneHand.dbc.csv")) do |row|
          hash[row[0].to_s] = row
        end
      end
    end

    def item_bonus_trees
      @@item_bonus_trees ||= Hash.new.tap do |hash|
        FasterCSV.foreach(File.join(File.dirname(__FILE__), 'data', 'WoD_item_bonus_tree_data.csv')) do |row|
          hash[row[1].to_s] = row
        end
      end
    end

    def item_bonus_data
      @@item_bonus_data ||= Hash.new.tap do |hash|
        FasterCSV.foreach(File.join(File.dirname(__FILE__), 'data', 'WoD_item_bonus_data.csv')) do |row|
          hash[row[0].to_s] = row
        end
      end
    end

    def populate_weapon_stats!
      doc = Nokogiri::XML open("http://www.wowhead.com/item=%d&xml" % @properties[:id], 'User-Agent' => 'Mozilla/5.0 (Windows NT 6.3; WOW64; rv:27.0) Gecko/20100101 Firefox/27.0').read
      eqstats = JSON::load("{%s}" % doc.css("jsonEquip").text)
      stats = JSON::load("{%s}" % doc.css("json").text)
      unless eqstats["mlespeed"].blank? and eqstats["speed"].blank?
        @properties[:speed] = (eqstats["mlespeed"] || eqstats["speed"]).to_f
        self.dps = (eqstats["mledps"] || eqstats["dps"]).to_f
        @properties[:subclass] = stats["subclass"].to_i
      end
    end

    def get_item_stats_wowhead
      stats = {}
      doc = Nokogiri::XML open("http://www.wowhead.com/item=%d&xml" % @properties[:id], 'User-Agent' => 'Mozilla/5.0 (Windows NT 6.3; WOW64; rv:27.0) Gecko/20100101 Firefox/27.0').read
      eqstats = JSON::load("{%s}" % doc.css("jsonEquip").text)
      stats1 = JSON::load("{%s}" % doc.css("json").text)
      eqstats.each do |stat, val|
        stat2 = WOWHEAD_MAP[stat]
        unless stat2.nil?
          stats[stat2] = val
        end
      end
      puts stats.inspect
      stats
    end

    def is_hydraulic_gem
      doc = Nokogiri::XML open("http://www.wowhead.com/item=%d&xml" % @properties[:id], 'User-Agent' => 'Mozilla/5.0 (Windows NT 6.3; WOW64; rv:27.0) Gecko/20100101 Firefox/27.0').read
      eqstats = JSON::load("{%s}" % doc.css("jsonEquip").text)
      stats1 = JSON::load("{%s}" % doc.css("json").text)
      ret = false
      if stats1["classs"] == 3 and stats1["subclass"] == 9
        ret = true
      end
      ret
    end

    def populate_stats
      # 1. if gem, take data from community api
      # 2. if random_suffix, update item name
      # 3. set new ilevel based on upgrade_level and item quality
      # 4. populate item data
      # 5. if random_suffix populate random suffix data
      # 6. if weapon update dps
      unless @properties[:gem_slot].nil?
        self.stats = @properties[:stats]
        return
      end
      @ori_ilevel = @properties[:ilevel]
      unless self.random_suffix.nil?
        if !@properties[:name].include? 'of the' or @properties[:name].include? 'Bracers of the Midnight Comet'
          row = random_suffixes[self.random_suffix.abs.to_s]
          unless row.nil?
            suffix = row[1]
          end
          suffix ||= ""
          self.name = @properties[:name] + " #{suffix}"
        end
      end

      upgd_lvl = 0
      if not self.upgrade_level.nil? and @properties[:upgradable]
        upgd_lvl = self.upgrade_level
      end
      if @properties[:quality] == 3
        upgrade_level_steps = 8
      else
        upgrade_level_steps = 4
      end
      @properties[:ilevel] = @properties[:ilevel] + upgd_lvl * upgrade_level_steps
      populate_item_upgrade_level
      unless self.random_suffix.nil?
        populate_item_upgrade_level_with_random_suffix
      end
      # if weapon: update dps
      if not @properties[:speed].nil? and not @properties[:speed].blank?
        row = item_damage_one_hand[@properties[:ilevel].to_s]
        if @properties[:quality] > 4
          self.dps = row[1+4].to_f
        else
          self.dps = row[1+@properties[:quality]].to_f
        end
      end
      puts "#{self.name} #{@properties[:tag]} #{@properties[:ilevel]}"
      puts self.stats.inspect
    end

    def get_bonus_data_rows(bonus_id)
      bonus_data_rows = []
      item_bonus_data.each_value do |row|
        if row[1] == bonus_id
          bonus_data_rows.push(row)
        end
      end
      return bonus_data_rows
    end

    SCAN_ATTRIBUTES = ['agility', 'strength', 'intellect', 'spirit', 'stamina', 'attack power', 'critical strike', 'versatility', 'multistrike',
                       'haste', 'mastery', 'pvp resilience', 'pvp power', 'all stats', 'dodge', 'block', 'parry'
    ]
    SCAN_OVERRIDE = { 'critical strike' => 'crit',
                        #"hit" => "hit rating",
                        #"expertise" => "expertise rating",
                        #"haste" => "haste rating",
                        #"mastery" => "mastery rating",
                        #"pvp resilience" => "resilience",
                        #"pvp power" => "pvp power rating"
                      }

    def scan_str(str)
      map = SCAN_ATTRIBUTES.map do |attr|
        if str =~/\+(\d+) (#{attr})/i
          qty = $1.to_i
          [(SCAN_OVERRIDE[attr] || attr).gsub(/ /, "_").to_sym, qty]
        elsif str =~/Equip:.*(#{attr}) by (\d+)/i
          qty = $2.to_i
          [(SCAN_OVERRIDE[attr] || attr).gsub(/ /, "_").to_sym, qty]
        else
          nil
        end
      end.compact
      Hash[*map.flatten]
    end

    def fix_gem_colors(color)
      return nil if color.nil?
      case color
      when 'Red or Yellow'
        return 'Orange'
      when 'Red or Blue'
        return 'Purple'
      when 'Blue or Yellow', 'Yellow or Blue'
        return 'Green'
      else
        color
      end
    end

    def quality_index(quality)
      case quality
      when 2
        return 2
      when 3
        return 1
      when 4
        return 0
      else
        return 0
      end
    end

    def slot_index(slot)
      case slot
      when 1, 5, 7
        return 0
      when 3, 6, 8, 10, 12
        return 1
      when 2, 9, 11, 16, 22
        return 2   
      when 13, 21
        return 3
      when 15
        return 4
      else
        return 2
      end
    end
  end
end
