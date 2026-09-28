# Project Instructions

- Do not run developer tool checks such as linters, formatters, Rojo checks, or other validation commands unless the user explicitly asks for them.
- Prefer editing the requested Lua files directly and keep changes narrowly scoped.
- Treat controllers required in `KnitStart` as available after they are assigned; do not add defensive nil checks around those controller fields.

# Game Context

This is a dinosaur-bone digging game with a competitive shared-world collection loop:

- Each player owns a base.
- Players leave their bases to locate piles of dirt in the shared world.
- Players dig piles with a shovel, trowel, or similar tool. Any player can dig any pile, creating competition for the best and largest piles.
- Players can slap other players to interrupt their digging.
- Completing a pile awards a set of bones. Players carry the bones back to their own base and place them there.
- Placed bones animate into walking skeletons that generate income and provide visual appeal and bragging rights.
