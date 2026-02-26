# Access Code Manager Specification

**Source:** `scripts/setgrove.sh` (29 lines)

## Purpose
Interactive utility to set or change the 6-character access code used to gate system launch.

## Execution Flow
1. Prompt for new code (hidden input)
2. Prompt for confirmation (hidden input)
3. Validate codes match
4. Validate length is exactly 6 characters
5. SHA-256 hash the code
6. Write hash to `.grvmap` file
7. Set permissions to 600

## Validation Rules
| Rule | Check | Error Message |
|------|-------|---------------|
| Codes match | `$INPUT_CODE != $CONFIRM_CODE` | "Codes do not match. Aborted." |
| Length check | `${#INPUT_CODE} -ne 6` | "Code must be exactly 6 characters." |

## Hashing
```bash
echo -n "$INPUT_CODE" | shasum -a 256 | awk '{print $1}'
```
- Uses `echo -n` to avoid trailing newline
- `shasum -a 256` — macOS built-in SHA-256
- `awk '{print $1}'` — extracts hash, drops filename placeholder

## Storage
| Attribute | Value |
|-----------|-------|
| File | `~/.systemname/.sys/.grvmap` |
| Format | Single line, 64-character hex SHA-256 hash |
| Permissions | 600 (owner read/write only) |

## Invocation
```bash
~/.systemname/.sys/setgrove.sh
```
Also called automatically at the end of `install.sh`.

## Known Issues
- No minimum complexity requirements
- No restriction on character types (spaces, special chars all allowed)
- No "current code" verification when changing (anyone with file access can change it)
- No backup of previous hash
