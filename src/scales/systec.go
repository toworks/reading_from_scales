/*

	известны под именем БУЛАТ

*/

package scales

import (
	"fmt"
	"regexp"
	"strings"
	"time"
)

const TimeFormatReverse string = "02.01.06 15:04:05"
const TimeFormatDirect string = "01.02.06 15:04:05"

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

  for i, v := range values {
	values[i] = strings.TrimSpace(v)
  }

  _id_scales := fmt.Sprintf("%d", c.Id_scale)
  _timestamp := c.get_datetime(values[0])
  _weight := values[1]
  _weight_platform_1 := values[5]
  _weight_platform_2 := values[9]
  _weight_stabilized_1 := values[4]
  _weight_stabilized_2 := values[4]

  if DEBUG.enable {
    c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec message: %#v", mod_name, msg)
	c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec values: %#v", mod_name, values)
	c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _timestamp: %s", mod_name, _id_scales, _timestamp)
	c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _weight: %s", mod_name, _id_scales, _weight)
	c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _weight_platform_1: %s", mod_name, _id_scales, _weight_platform_1)
	c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _weight_platform_2: %s", mod_name, _id_scales, _weight_platform_2)
	c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _weight_stabilized_1: %s", mod_name, _id_scales, _weight_stabilized_1)
	c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _weight_stabilized_2: %s", mod_name, _id_scales, _weight_stabilized_2)
  }
}

func (c *Config) Processing_systec_v2(message string) {
  messages := regexp.MustCompile(`\w\d\[.*?\]`).FindAllString(message, -1)

  var _id_scales, _timestamp, _weight, _weight_stabilized_1, _weight_stabilized_2,
      _weight_stabilized_3, _w1, _w2, _w3, _w4, _h_bias_weight, _l_bias_weight string

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
			if len(values) > 7 {
				if DEBUG.enable {
					c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message type: W1  values: %#v", mod_name, values)
				}
				_id_scales = fmt.Sprintf("%d", c.Id_scale)
				_timestamp = c.get_datetime(values[0])
				_weight = values[3]
				_h_bias_weight = values[7]
				_l_bias_weight = values[6]
			}
		}
		if regexp.MustCompile(`(?is)^P1`).MatchString(msg) {
			if DEBUG.enable {
				c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message P1: %#v", mod_name, msg)
			}
			values := c.Processing_systec_v2_create_array(msg)
			if len(values) > 6 {
				if DEBUG.enable {
					c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message type: P1  values: %#v", mod_name, values)
				}
				_weight_stabilized_1 = values[2]
			}
		}
		if regexp.MustCompile(`(?is)^P2`).MatchString(msg) {
			if DEBUG.enable {
				c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message P2: %#v", mod_name, msg)
			}
			values := c.Processing_systec_v2_create_array(msg)
			if len(values) > 6 {
				if DEBUG.enable {
					c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message type: P2  values: %#v", mod_name, values)
				}
				_weight_stabilized_2 = values[2]
			}
		}
		if regexp.MustCompile(`(?is)^P3`).MatchString(msg) {
			if DEBUG.enable {
				c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message P3: %#v", mod_name, msg)
			}
			values := c.Processing_systec_v2_create_array(msg)
			if len(values) > 6 {
				if DEBUG.enable {
					c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message type: P3  values: %#v", mod_name, values)
				}
				_weight_stabilized_3 = values[2]
			}
		}
		if regexp.MustCompile(`(?is)^S1`).MatchString(msg) {
			if DEBUG.enable {
				c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message S1: %#v", mod_name, msg)
			}
			values := c.Processing_systec_v2_create_array(msg)
			if len(values) > 5 {
				if DEBUG.enable {
					c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message type: S1  values: %#v", mod_name, values)
				}
				_w1 = values[3]
			}
		}
		if regexp.MustCompile(`(?is)^S2`).MatchString(msg) {
			if DEBUG.enable {
				c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message S2: %#v", mod_name, msg)
			}
			values := c.Processing_systec_v2_create_array(msg)
			if len(values) > 5 {
				if DEBUG.enable {
					c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message type: S2  values: %#v", mod_name, values)
				}
				_w2 = values[3]
			}
		}
		if regexp.MustCompile(`(?is)^S3`).MatchString(msg) {
			if DEBUG.enable {
				c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message S3: %#v", mod_name, msg)
			}
			values := c.Processing_systec_v2_create_array(msg)
			if len(values) > 5 {
				if DEBUG.enable {
					c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message type: S3  values: %#v", mod_name, values)
				}
				_w3 = values[3]
			}
		}
		if regexp.MustCompile(`(?is)^S4`).MatchString(msg) {
			if DEBUG.enable {
				c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message S4: %#v", mod_name, msg)
			}
			values := c.Processing_systec_v2_create_array(msg)
			if len(values) > 5 {
				if DEBUG.enable {
					c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec V2 message type: S4  values: %#v", mod_name, values)
				}
				_w4 = values[3]
			}
		}
	}
	if DEBUG.enable {
		c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _timestamp: %s", mod_name, _id_scales, _timestamp)
		c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _weight: %s", mod_name, _id_scales, _weight)
		c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _weight_stabilized_1: %s", mod_name, _id_scales, _weight_stabilized_1)
		c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _weight_stabilized_2: %s", mod_name, _id_scales, _weight_stabilized_2)
		c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _weight_stabilized_3: %s", mod_name, _id_scales, _weight_stabilized_3)
		c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _w1: %s", mod_name, _id_scales, _w1)
		c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _w2: %s", mod_name, _id_scales, _w2)
		c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _w3: %s", mod_name, _id_scales, _w3)
		c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _w4: %s", mod_name, _id_scales, _w4)
		c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _h_bias_weight: %s", mod_name, _id_scales, _h_bias_weight)
		c.ch_message <- fmt.Sprintf("d|:|%s: Processing Systec  id_scale: %s  _l_bias_weight: %s", mod_name, _id_scales, _l_bias_weight)
	}
  }
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
  dt, err := time.Parse(TimeFormatReverse, timestamp)
  if err != nil {
	c.ch_message <- fmt.Sprintf("e|:|%s: format: TimeFormatReverse  error: %s\n", mod_name, err.Error())
	dt, err = time.Parse(TimeFormatDirect, timestamp)
	if err != nil {
		c.ch_message <- fmt.Sprintf("e|:|%s: format: TimeFormatDirect  error: %s\n", mod_name, err.Error())
		dt, err = time.Parse(TimeFormatReverse, timestamp)
	}
  }
  if err != nil {
	return time.Now().Format(TimeFormat)
  } else {
	return dt.Format(TimeFormat)
  }
}
