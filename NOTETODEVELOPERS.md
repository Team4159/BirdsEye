## Assumptions
### Analysis System
- Team Points Added are linearly independent
- Team Points Added are normally distributed

### Defense Heuristic System
- Match Scouting Fields, post-aggregation
  - comments_agility: float4 [0, 1]
  - comments_fouls: int2 [0,infinity)
  - comments_defensive: float4 [0, 1]

## Hard Limitations
- TBA must always be accessible and updated
  - used in triggers to validate everything

### Column Constraints (Match Scouting)
- Season cannot exceed 32,767 [15 bits]
- Match must match `/^(q|((qf|sf|f)\d{1,2}))m\d{1,3}$/` (case-sensitive)
- Team must match `/^\d{1,5}[A-Z]?$/` (case-sensitive)
- The system can only handle 9,223,372,036,854,775,808 [9 quintillion] scouting entries

### Column Constraints (Pit Scouting)
- Same as Match Scouting EXCEPT
- Team must be numeric, 0 < team <= 99,999

### [match_code] Function
- Match Number cannot exceed 256 [0b100000000] [8 bits] (so no qm257)
- Set Number cannot exceed 31 [0b11111] [5 bits] (so no sf32m1)
- Match Level index cannot exceed 3 [0b11] [2 bits] (so no pm1)
  - index 0: qm, Index 1: qf, Index 2: sf, Index 3: f

8 + 5 + 2 = 15 bits = signed 2 byte int

To resolve this, there is one more bit we can allot by starting from -32767. Or switch to int4.

<em> This list is incomplete.