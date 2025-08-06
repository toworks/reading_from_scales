/*

    протокол: ASCII
    информация: ЄТМ-ВВТ-С
    контроллер: ВП-89.02 (wp8902)

*/

package scales

import (
  "fmt"
  "regexp"
  "strings"
  //"strconv"

  db "reading_from_scales/src/database"
)

type _wp8902 struct {
  command              string
  number_platforms     int
  read_number_platform int
  ok_read_weight       bool
  ok_number_platforms  bool
}

var (
  wp8902 = &_wp8902{number_platforms: 0, read_number_platform: 0}
)


func (c *Config) Processing_wp8902(message string) {
  if wp8902.command == "" {
	wp8902.command = c.Command
  }
///*
  if c.Command == "W4" {
	c.Command = "W"
  } else if c.Command == "W" {
	c.Command = "W1"
  } else if c.Command == "W1" {
	c.Command = "W2"
  } else if c.Command == "W2" {
	c.Command = "W3"
  } else if c.Command == "W3" {
	c.Command = "W4"
  }
  return
//*/
  if !wp8902.ok_number_platforms {
	c.set_number_platforms(message)
	//c.Command = wp8902.command + fmt.Sprintf("%d", wp8902.number_platforms)
  }/* else {
	if wp8902.ok_read_weight && wp8902.read_number_platform == 0 {
		wp8902.read_number_platform = 1
	}
	if !wp8902.ok_read_weight {
		c.Command = wp8902.command
		if DEBUG.enable {
			c.ch_message <- fmt.Sprintf("d|:|%s: Processing wp-89.02: we get weight and stabilization", mod_name)
		}
	}
	if wp8902.ok_read_weight {
		c.Command = wp8902.command + fmt.Sprintf("%d", wp8902.read_number_platform)
		if DEBUG.enable {
			c.ch_message <- fmt.Sprintf("d|:|%s: Processing wp-89.02: we get the weight on the platform: %d", mod_name, wp8902.read_number_platform)
		}
	}
	c._processing_wp8902(message)
  }*/
}

func (c *Config) _processing_wp8902(message string) {
  msg := strings.ReplaceAll(message, "\r\n", "#")

  if c.check_error(message) || !c.check_receive_cmd(message) {
    return
  }

  values := strings.Split(msg, "#")

  if len(values) <= 1 { return }

  msg = regexp.MustCompile("(?m)^\\s").ReplaceAllString(values[1], "$1")
  values = strings.Split(msg, ` `)

  if len(values) <= 1 { return }

  if !wp8902.ok_read_weight && values[1] == "1" {
	c.ch_message <- fmt.Sprintf("d|:|%s: ======= %s: %#v", mod_name, c.Command, values[1])
	wp8902.ok_read_weight = true
return
  }

  if wp8902.ok_read_weight && wp8902.ok_number_platforms {
	c.ch_message <- fmt.Sprintf("d|:|%s: <<<>>> platform: %d of %d  values: %#v", mod_name, wp8902.read_number_platform, wp8902.number_platforms, values)
	if wp8902.read_number_platform != wp8902.number_platforms {
		wp8902.read_number_platform += 1
	} else {
		wp8902.read_number_platform = 1
		wp8902.ok_read_weight = false
	}
  }


  kaw := db.Kep_analytics_weight{}
  if DEBUG.enable {
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing wp-89.02 message: '%v'", mod_name, message)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing wp-89.02 values: '%#v'", mod_name, values)
  }

  kaw.Id_scales = fmt.Sprintf("%d", c.Id_scale)
  kaw.Timestamp = c.get_datetime("")
/*
  if ! c.check_disabled_parameter(`weight`) && len(values) >= index {
    if _, err := strconv.Atoi(c.get_value(values[index])); err == nil {
        kaw.Weight = c.get_value(values[index])
    }
  }
*//*
  if ! c.check_disabled_parameter(`weight_platform_1`) && len(values) >= index {
    if _, err := strconv.Atoi(c.get_value(values[index])); err == nil {
        kaw.Weight_platform_1 = c.get_value(values[index])
    }
  }
  if ! c.check_disabled_parameter(`weight_stabilized_1`) && len(values) >= index {
    kaw.Weight_stabilized_1 = "1"
  }/*
/*
  if DEBUG.enable {
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing wp-89.02  message: %#v", mod_name, msg)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing wp-89.02  values: %#v", mod_name, values)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing wp-89.02  id_scale: %s  timestamp: %s", mod_name, kaw.Id_scales, kaw.Timestamp)
//    c.ch_message <- fmt.Sprintf("d|:|%s: Processing wp-89.02  id_scale: %s  weight: %s", mod_name, kaw.Id_scales, kaw.Weight)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing wp-89.02  id_scale: %s  weight_platform_1: %s", mod_name, kaw.Id_scales, kaw.Weight_platform_1)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing wp-89.02  id_scale: %s  weight_stabilized_1: %s", mod_name, kaw.Id_scales, kaw.Weight_stabilized_1)
  }

  select {
    case c.ch_db_message <- kaw:
    default:
  }*/
}

func (c *Config) set_number_platforms(message string) {
//  if wp8902.number_platforms == 0 {
	wp8902.number_platforms += 1
	c.Command = wp8902.command + fmt.Sprintf("%d", wp8902.number_platforms)
	return
//  }
  if DEBUG.enable {
    c.ch_message <- fmt.Sprintf("d|:|%s: set number platforms: %d  ok_number_platforms: %t  in", mod_name, wp8902.number_platforms, wp8902.ok_number_platforms)
  }
  if c.check_error(message) {
    wp8902.number_platforms -= 1
    wp8902.ok_number_platforms =  true
	c.ch_message <- fmt.Sprintf("i|:|%s: set number platforms: %d", mod_name, wp8902.number_platforms)
  }
  if len(message) >= 57 {
    if !c.check_error(message) && !wp8902.ok_number_platforms {
        c.ch_message <- fmt.Sprintf("d|:|%s: >>>>>>>>>>", mod_name)
        wp8902.number_platforms += 1
		c.Command = wp8902.command + fmt.Sprintf("%d", wp8902.number_platforms)
    }
  }
  if DEBUG.enable {
    c.ch_message <- fmt.Sprintf("d|:|%s: set number platforms: %d  ok_number_platforms: %t  out", mod_name, wp8902.number_platforms, wp8902.ok_number_platforms)
  }
}

func (c *Config) check_error(message string) bool {
  msg := strings.ReplaceAll(message, "\r\n", "")
  if len(message) >= 10 {
    if regexp.MustCompile(`(?is)ERROR`).MatchString(msg) {
	    c.ch_message <- fmt.Sprintf("e|:|%s: Processing wp-89.02: 'ERROR' in answer", mod_name)
        return true
    }
  }
  return false
}

func (c *Config) check_badcmd(message string) bool {
  msg := strings.ReplaceAll(message, "\r\n", "")
  if len(message) >= 10 {
    if regexp.MustCompile(`(?is)BADCMD`).MatchString(msg) {
		c.ch_message <- fmt.Sprintf("e|:|%s: Processing wp-89.02: 'BADCMD' in answer", mod_name)
        return true
    }
  }
  return false
}

func (c *Config) check_receive_cmd(message string) bool {
  msg := strings.ReplaceAll(message, "\r\n", "")
  msg = regexp.MustCompile("(?m)^(.*)\\r.*").ReplaceAllString(msg, "$1")
  if regexp.MustCompile(`(?is)^` + c.Command).MatchString(msg) {
    return true
  }
  c.ch_message <- fmt.Sprintf("e|:|%s: Processing wp-89.02: response command does not match the request: send: %s  recieve: %s", mod_name, c.Command, msg)
  return false
}
