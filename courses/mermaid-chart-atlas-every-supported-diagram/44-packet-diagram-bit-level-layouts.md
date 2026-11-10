---
title: 'Packet diagram: bit-level layouts'
---
## Packet diagram: bit-level layouts

**Atlas example 21 of 44**

Use a packet diagram to explain protocol headers and the exact bit ranges occupied by each field.

### Core Mermaid elements
- packet-beta starts the layout; title names the structure.
- 0-15: "Field" assigns an inclusive bit range.
- A single bit uses one number such as 106.
- Fields are rendered in order across fixed-width rows.

### Build it well
1. Keep ranges ordered and non-overlapping.
2. Use the protocol’s real bit numbering.
3. Name flags individually when they matter.
4. Check that the final range matches the expected packet size.

> Packet diagrams are ideal for binary structure, not general data models.

<!-- ds-course-column:2 type=markdown -->

## Working example

```mermaid
packet-beta
  title TCP packet structure
  0-15: "Source port"
  16-31: "Destination port"
  32-63: "Sequence number"
  64-95: "Acknowledgement number"
  96-99: "Data offset"
  100-105: "Reserved"
  106: "URG"
  107: "ACK"
  108: "PSH"
  109: "RST"
  110: "SYN"
  111: "FIN"
  112-127: "Window size"
  128-143: "Checksum"
  144-159: "Urgent pointer"
```

Use the chart controls to zoom, fit, open fullscreen, or inspect the exact source.
