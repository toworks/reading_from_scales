/*

  известны под именем БУЛАТ

*/

package scales

import (
  "fmt"
  "regexp"
  "strings"
  "time"

  db "reading_from_scales/src/database"
)

var TimeFormatArray = []string {"2006-01-02 15:04:05.000",
                                "06-01-02 15:04:05",
                                "02.01.06 15:04:05",
                                "01.02.06 15:04:05",
                                "02.01.06 15:04",
                                "01.02.06 15:04"}


func (c *Config) Processing_systec(message string) {
  if regexp.MustCompile(`(?is)^$|v1`).MatchString(c.Protocol) {
    c.Processing_systec_v1(message)
  } else if regexp.MustCompile(`(?is)^$|v2`).MatchString(c.Protocol) && regexp.MustCompile(`(?is)<SD>`).MatchString(c.Command) {
    c.Processing_systec_v2(message)
  }
}

func (c *Config) Processing_systec_v1(message string) {
  msg := regexp.MustCompile("(?m).*<(.*);>[\\n\\r]+.*").ReplaceAllString(message, "$1")

  values := strings.Split(msg, ";")

  if len(values) == 0 { return }

  for i, v := range values {
    values[i] = strings.TrimSpace(v)
  }

  kaw := db.Kep_analytics_weight{}
  if DEBUG.enable {
	c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec message: count: %v", mod_name, len(values))
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec message: %#v", mod_name, kaw)
  }

  kaw.Id_scales = fmt.Sprintf("%d", c.Id_scale)
  kaw.Timestamp = c.get_datetime(values[0])
  if ! c.check_disabled_parameter(`weight`) && len(values) >= 2 {
    kaw.Weight = values[1]
  }
  if ! c.check_disabled_parameter(`weight_platform_1`) && len(values) >= 6 {
    kaw.Weight_platform_1 = values[5]
  }
  if ! c.check_disabled_parameter(`weight_platform_2`) && len(values) >= 10 {
    kaw.Weight_platform_2 = values[9]
  }
  if ! c.check_disabled_parameter(`weight_stabilized_1`) && len(values) >= 5 {
    kaw.Weight_stabilized_1 = values[4]
  }
  if ! c.check_disabled_parameter(`weight_stabilized_2`) && len(values) >= 5 {
    kaw.Weight_stabilized_2 = values[4]
  }
  if len(values) >= 30 {
	  if ! c.check_disabled_parameter(`w1`) {
		kaw.W1 = values[14]
	  }
	  if ! c.check_disabled_parameter(`w2`) {
		kaw.W2 = values[19]
	  }
	  if ! c.check_disabled_parameter(`w3`) {
		kaw.W3 = values[24]
	  }
	  if ! c.check_disabled_parameter(`w4`) {
		kaw.W4 = values[29]
	  }
  }

  if DEBUG.enable {
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  message: %#v", mod_name, msg)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  values: %#v", mod_name, values)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  timestamp: %s", mod_name, kaw.Id_scales, kaw.Timestamp)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  weight: %s", mod_name, kaw.Id_scales, kaw.Weight)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  weight_platform_1: %s", mod_name, kaw.Id_scales, kaw.Weight_platform_1)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  weight_platform_2: %s", mod_name, kaw.Id_scales, kaw.Weight_platform_2)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  weight_stabilized_1: %s", mod_name, kaw.Id_scales, kaw.Weight_stabilized_1)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  weight_stabilized_2: %s", mod_name, kaw.Id_scales, kaw.Weight_stabilized_2)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  w1: %s", mod_name, kaw.Id_scales, kaw.W1)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  w2: %s", mod_name, kaw.Id_scales, kaw.W2)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  w3: %s", mod_name, kaw.Id_scales, kaw.W3)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  w4: %s", mod_name, kaw.Id_scales, kaw.W4)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  h_bias_weight: %s", mod_name, kaw.Id_scales, kaw.H_bias_weight)
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  l_bias_weight: %s", mod_name, kaw.Id_scales, kaw.L_bias_weight)
  }

  select {
	case c.ch_db_message <- kaw:
	default:
  }
}

func (c *Config) Processing_systec_v2(message string) {
  messages := regexp.MustCompile(`\w\d\[.*?\]`).FindAllString(message, -1)

  kaw := db.Kep_analytics_weight{}
  c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message: %#v", mod_name, kaw)

  if DEBUG.enable {
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 messages count: %d  array: %#v", mod_name, len(messages), messages)
  }

  if len(messages) == 7 {
      for _, msg := range messages {
        if DEBUG.enable {
          c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message: %#v", mod_name, msg)
        }
        if regexp.MustCompile(`(?is)^W1`).MatchString(msg) {
          if DEBUG.enable {
            c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message W1: %#v", mod_name, msg)
          }
          values := c.Processing_systec_v2_create_array(msg)
          if len(values) > 8 {
            if DEBUG.enable {
              c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message type: W1  values: %#v", mod_name, values)
            }
            kaw.Id_scales = fmt.Sprintf("%d", c.Id_scale)
            kaw.Timestamp = c.get_datetime(values[0])
            if ! c.check_disabled_parameter(`weight`) {
                kaw.Weight = values[3]
            }
            if ! c.check_disabled_parameter(`h_bias_weight`) {
                kaw.H_bias_weight = values[7]
            }
            if ! c.check_disabled_parameter(`l_bias_weight`) {
                kaw.L_bias_weight = values[6]
            }
          }
        }
        if regexp.MustCompile(`(?is)^P1`).MatchString(msg) {
          if DEBUG.enable {
            c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message P1: %#v", mod_name, msg)
          }
          values := c.Processing_systec_v2_create_array(msg)
          if len(values) > 4 {
            if DEBUG.enable {
              c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message type: P1  values: %#v", mod_name, values)
            }
            if ! c.check_disabled_parameter(`weight_platform_1`) {
                kaw.Weight_platform_1 = values[3]
            }
            if ! c.check_disabled_parameter(`weight_stabilized_1`) {
                kaw.Weight_stabilized_1 = values[2]
            }
          }
        }
        if regexp.MustCompile(`(?is)^P2`).MatchString(msg) {
          if DEBUG.enable {
            c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message P2: %#v", mod_name, msg)
          }
          values := c.Processing_systec_v2_create_array(msg)
          if len(values) > 4 {
            if DEBUG.enable {
              c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message type: P2  values: %#v", mod_name, values)
            }
            if ! c.check_disabled_parameter(`weight_platform_2`) {
                kaw.Weight_platform_2 = values[3]
            }
            if ! c.check_disabled_parameter(`weight_stabilized_2`) {
                kaw.Weight_stabilized_2 = values[2]
            }
          }
        }
        if regexp.MustCompile(`(?is)^P3`).MatchString(msg) {
          if DEBUG.enable {
            c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message P3: %#v", mod_name, msg)
          }
          values := c.Processing_systec_v2_create_array(msg)
          if len(values) > 4 {
            if DEBUG.enable {
              c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message type: P3  values: %#v", mod_name, values)
            }
            if ! c.check_disabled_parameter(`weight_platform_3`) {
                kaw.Weight_platform_3 = values[3]
            }
            if ! c.check_disabled_parameter(`weight_stabilized_3`) {
                kaw.Weight_stabilized_3 = values[2]
            }
          }
        }
        if regexp.MustCompile(`(?is)^S1`).MatchString(msg) {
          if DEBUG.enable {
            c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message S1: %#v", mod_name, msg)
          }
          values := c.Processing_systec_v2_create_array(msg)
          if len(values) > 4 {
            if DEBUG.enable {
              c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message type: S1  values: %#v", mod_name, values)
            }
            if ! c.check_disabled_parameter(`w1`) {
                kaw.W1 = values[3]
            }
          }
        }
        if regexp.MustCompile(`(?is)^S2`).MatchString(msg) {
          if DEBUG.enable {
            c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message S2: %#v", mod_name, msg)
          }
          values := c.Processing_systec_v2_create_array(msg)
          if len(values) > 4 {
            if DEBUG.enable {
              c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message type: S2  values: %#v", mod_name, values)
            }
            if ! c.check_disabled_parameter(`w2`) {
                kaw.W2 = values[3]
            }
          }
        }
        if regexp.MustCompile(`(?is)^S3`).MatchString(msg) {
          if DEBUG.enable {
            c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message S3: %#v", mod_name, msg)
          }
          values := c.Processing_systec_v2_create_array(msg)
          if len(values) > 4 {
            if DEBUG.enable {
              c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message type: S3  values: %#v", mod_name, values)
            }
            if ! c.check_disabled_parameter(`w3`) {
                kaw.W3 = values[3]
            }
          }
        }
        if regexp.MustCompile(`(?is)^S4`).MatchString(msg) {
          if DEBUG.enable {
            c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message S4: %#v", mod_name, msg)
          }
          values := c.Processing_systec_v2_create_array(msg)
          if len(values) > 4 {
            if DEBUG.enable {
              c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message type: S4  values: %#v", mod_name, values)
            }
            if ! c.check_disabled_parameter(`w4`) {
                kaw.W4 = values[3]
            }
          }
        }
      }
      if DEBUG.enable {
        c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2  id_scale: %s  timestamp: %s", mod_name, kaw.Id_scales, kaw.Timestamp)
        c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2  id_scale: %s  weight: %s", mod_name, kaw.Id_scales, kaw.Weight)
        c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2  id_scale: %s  Weight_platform_1: %s", mod_name, kaw.Id_scales, kaw.Weight_platform_1)
        c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2  id_scale: %s  Weight_platform_2: %s", mod_name, kaw.Id_scales, kaw.Weight_platform_2)
        c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2  id_scale: %s  Weight_platform_3: %s", mod_name, kaw.Id_scales, kaw.Weight_platform_3)
        c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2  id_scale: %s  weight_stabilized_1: %s", mod_name, kaw.Id_scales, kaw.Weight_stabilized_1)
        c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2  id_scale: %s  weight_stabilized_2: %s", mod_name, kaw.Id_scales, kaw.Weight_stabilized_2)
        c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2  id_scale: %s  weight_stabilized_3: %s", mod_name, kaw.Id_scales, kaw.Weight_stabilized_3)
        c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2  id_scale: %s  w1: %s", mod_name, kaw.Id_scales, kaw.W1)
        c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2  id_scale: %s  w2: %s", mod_name, kaw.Id_scales, kaw.W2)
        c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2  id_scale: %s  w3: %s", mod_name, kaw.Id_scales, kaw.W3)
        c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2  id_scale: %s  w4: %s", mod_name, kaw.Id_scales, kaw.W4)
        c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2  id_scale: %s  h_bias_weight: %s", mod_name, kaw.Id_scales, kaw.H_bias_weight)
        c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2  id_scale: %s  l_bias_weight: %s", mod_name, kaw.Id_scales, kaw.L_bias_weight)
      }
  }

  select {
	case c.ch_db_message <- kaw:
	default:
  }
}

func (c *Config) check_disabled_parameter(match string) bool {
  var pattern string

  if c.Disabled_parameters != "" {
    pattern = "(?is)"+c.Disabled_parameters
  } else {
    pattern = "(?is)^!" + match + "$"
  }
  res := regexp.MustCompile(pattern).MatchString(match)
  if DEBUG.enable {
    c.ch_message <- fmt.Sprintf("d|:|%s: disabled parameters patern: %s  match: %s  status: %v", mod_name, pattern, match, res)
  }
  return res
}

func (c *Config) Processing_systec_v2_create_array(message string) []string {
  msg := regexp.MustCompile("^\\w\\d\\[(.*);\\]$").ReplaceAllString(message, "$1")

  values := strings.Split(msg, ";")

  for i, v := range values {
  values[i] = strings.TrimSpace(v)
  }

  if DEBUG.enable {
	c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 create array: %#v", mod_name, values)
  }
  return values
}

func (c *Config) get_datetime(timestamp string) string {
  var dt time.Time
  var err error
  if !c.Local_timestamp {
	for _, time_format := range TimeFormatArray {
		dt, err = time.Parse(time_format, timestamp)
		if err != nil {
			c.ch_message <- fmt.Sprintf("w|:|%s: time format: %s", mod_name, err.Error())
		} else {
			return dt.Format(TimeFormat)
		}
	}
  }
  if ( err != nil && !c.Local_timestamp ) || c.Local_timestamp {
	c.ch_message <- fmt.Sprintf("w|:|%s: time format: local timestamp is applied", mod_name)
	local_timestamp := time.Now().Format(TimeFormat)
	if DEBUG.enable {
		c.ch_message <- fmt.Sprintf("d|:|%s: timestamp remote: '%s'  local: %#v", mod_name, timestamp, local_timestamp)
	}
    return local_timestamp
  }
  return dt.Format(TimeFormat)
}
