#!/usr/bin/env bash
# Copyright © 2026 Ping Identity Corporation

#
# Ping Identity DevOps - CI scripts
#
# This script parses Dockerfiles and hooks to create AsciiDoc docs
# (PDI-2517), staged for the Antora portal repo (docs-devops-getting-started).
#
# Output layout mirrors the portal:
#   ${OUTPUT_DIR}/docker-images/<image>/README.adoc
#   ${OUTPUT_DIR}/docker-images/<image>/hooks/<hook>.adoc
#   ${OUTPUT_DIR}/docker-images/<image>/hooks/README.adoc
#
# Syncing to the portal repo is a separate step (sync_portal_docs.sh); CI runs
# this script only to detect drift (regenerate + diff), never to publish.
#
test "${VERBOSE}" = "true" && set -x

if test -z "${CI_COMMIT_REF_NAME}"; then
    CI_PROJECT_DIR="$(
        cd "$(dirname "${0}")/.." || exit 97
        pwd
    )"
    test -z "${CI_PROJECT_DIR}" && echo "Invalid call to dirname ${0}" && exit 97
fi
CI_SCRIPTS_DIR="${CI_PROJECT_DIR:-.}/ci_scripts"
# shellcheck source=./ci_tools.lib.sh
. "${CI_SCRIPTS_DIR}/ci_tools.lib.sh"
# shellcheck source=./docs_image_info.lib.sh disable=SC2034
. "${CI_SCRIPTS_DIR}/docs_image_info.lib.sh"

TOOL_NAME="$(basename "${0}")"
OUTPUT_DIR="${DOCS_OUTPUT_DIR:-${TMPDIR:-/tmp}}"
DOCKER_BUILD_DIR="$(
    cd "$(dirname "${0}")"/.. || exit 97
    pwd
)"

# Legacy single-line ENV constraint (was deploy_docs.sh lines 260-262): the
# parser can only detect a line continuation at end of line, so an ENV value
# itself split across lines is unhandleable. Any Dockerfile rework must keep
# ENV values on a single line or generation breaks.

#
# Usage printing function
#
usage() {
    cat << END_USAGE
Usage: ${TOOL_NAME} {options}
    where {options} include:

    -d, --docker-image {docker-image}
        The name of the docker image to build docs for
    --dry-run
        Kept for compatibility; generation never touches git, so this is a no-op
    -h, --help
        Display general usage information
END_USAGE
    exit 99
}

#
# Append all arguments to the end of the current asciidoc document file
#
append_doc() {
    echo "$*" >> "${_docFile}"
}

#
# Append a header (blank separator line)
#
append_header() {
    append_doc ""
}

#
# Append a footer including a link to the source file
#
append_footer() {
    _srcFile="${1}"

    append_doc ""
    append_doc "'''"
    append_doc ""
    test -n "${_srcFile}" && append_doc "This document is auto-generated from _https://github.com/pingidentity/pingidentity-docker-builds/blob/master/${_srcFile}[${_srcFile}]_"
    append_doc ""
    append_doc "Copyright © 2026 Ping Identity Corporation"
}

#
# Append the page header: = title, :description:, then the hand intro prose
# and (when the map defines one) the Related Docker Images section. Page
# shape is fixed — no intro heading (the = title is the only title), all
# fixed sections at == (PDI-2518 alignment).
#
append_page_header() {
    _dockerImage="${1}"

    append_doc "= Ping Identity DevOps Docker Image - \`${_dockerImage}\`"
    append_doc ":description: ${IMG_DESCRIPTION}"
    append_doc ""
    append_doc "${IMG_INTRO_PROSE}"
    if test -n "${IMG_RELATED}"; then
        append_doc ""
        append_doc "[#devops-related-docker-images]"
        append_doc "== Related Docker Images"
        append_doc ""
        append_doc "${IMG_RELATED}"
    fi
}

#
# Start the section on environment variables
#
append_env_table_header() {
    if test "${ENV_TABLE_ACTIVE}" != "true"; then
        ENV_TABLE_ACTIVE="true"

        append_doc ""
        append_doc "[#devops-environment-variables]"
        append_doc "== Environment Variables"
        append_doc ""
        append_doc "The following environment \`ENV\` variables can be used with this image, in addition to any inherited from parent images."
        append_doc ""
        append_doc '[cols="1,2,4", options="header"]'
        append_doc "|==="
        append_doc "| ENV Variable"
        append_doc "| Default"
        append_doc "| Description"
        append_doc ""
    fi
}

#
# Close the ENV table (blank after the last row, then |===)
#
append_env_table_footer() {
    if test "${ENV_TABLE_ACTIVE}" = "true"; then
        append_doc ""
        append_doc "|==="
        ENV_TABLE_ACTIVE="false"
    fi
}

#
# Append an environment variable, default value and description
#
append_env_variable() {
    envVar="${1}" && shift
    envDesc="${1}" && shift
    envDef="${1}" && shift

    # Description text is concatenated by the parser with a trailing space per
    # #-- line; trim the tail and collapse nothing else (portal pages keep
    # their internal double spaces).
    # shellcheck disable=SC2001
    envDesc=$(echo "${envDesc}" | sed -e 's/[[:space:]]*$//')
    # shellcheck disable=SC2001
    envDef=$(echo "${envDef}" | sed -e 's/[[:space:]]*$//')

    # Unwrap shell-style defaults for asciidoc: ${VAR} renders as the
    # passthrough macro $+{VAR}+. A bare '$' default must stay quoted. Bare
    # URLs render as +url+ passthrough (PF_ADMIN_PUBLIC_BASEURL).
    case "${envDef}" in
        '$') ;;
        'http://'* | 'https://'*) envDef="+${envDef}+" ;;
        *'$'*)
            # shellcheck disable=SC2001
            envDef=$(echo "${envDef}" | sed -e 's/\${\([A-Za-z_][A-Za-z0-9_/:=-]*\)}/$+{\1}+/g')
            ;;
    esac
    # Glob tokens (*.log*) would pair as adoc emphasis between the asterisks.
    # Each star becomes a pass:[*] inline passthrough macro — exact rendering,
    # and safe next to the $+{VAR}+ passthroughs above (wrapping the whole
    # token in +...+ would emit adjacent "++" delimiters; a backslash-escaped
    # \* renders the backslash after a preceding passthrough).
    case "${envDef}" in
        *'*'*)
            # shellcheck disable=SC2001
            envDef=$(echo "${envDef}" | sed -e 's/\*/pass:[*]/g')
            ;;
    esac

    # Descriptions may reference env vars / globs too; same passthrough rules
    # so the cell renders literally (remove-defunct-server desc, TAIL_LOG_FILES
    # descriptions). Globs use the same pass:[*] star substitution as defaults.
    case "${envDesc}" in
        *'$'*)
            # shellcheck disable=SC2001
            envDesc=$(echo "${envDesc}" | sed -e 's/\${\([A-Za-z_][A-Za-z0-9_/:=-]*\)}/$+{\1}+/g')
            ;;
    esac
    case "${envDesc}" in
        *'*'*)
            # shellcheck disable=SC2001
            envDesc=$(echo "${envDesc}" | sed -e 's/\*/pass:[*]/g')
            ;;
    esac

    append_doc "| ${envVar}"
    if test -z "${envDef}"; then
        append_doc "|"
    else
        append_doc "| ${envDef}"
    fi
    if test -z "${envDesc}"; then
        append_doc "|"
    else
        append_doc "| ${envDesc}"
    fi
    append_doc ""
}

#
# append docs for exposed ports
#
append_expose_ports() {
    exposePorts="${1}"

    append_doc ""
    append_doc "[#devops-ports-exposed]"
    append_doc "== Ports Exposed"
    append_doc ""
    append_doc "The following ports are exposed from the container.  If a variable is used, then it may come from a parent container"
    append_doc ""

    for port in ${exposePorts}; do
        # EXPOSE values arrive as ${NAME} (render $\{NAME}) or literal 9022
        # (render as-is)
        # shellcheck disable=SC2001
        port=$(echo "${port}" | sed -e 's/^\${\([A-Za-z_][A-Za-z0-9_]*\)}$/\1/')
        case "${port}" in
            [0-9]*) append_doc "* ${port}" ;;
            *) append_doc '* $\{'"${port}"'}' ;;
        esac
    done

    append_doc ""
}

#
# parse all the hooks in a product's /opt/staging/hooks
#
parse_hooks() {
    _dockerImage="${1}"
    _hooksDir="${DOCKER_BUILD_DIR}/${_dockerImage}/opt/staging/hooks"

    mkdir -p "${OUTPUT_DIR}/docker-images/${_dockerImage}/hooks"

    banner "Parsing hooks for ${_dockerImage}..."

    _hookFiles=""

    #
    # The following creates a set of .../product/hooks/{hook-name}.adoc file for each hook
    # pulling in docs in that hook file.
    #
    for _hookFilePath in "${_hooksDir}"/*; do
        test -f "${_hookFilePath}" || continue
        _hookFile=$(basename "${_hookFilePath}")
        _hookFiles="${_hookFiles:+${_hookFiles} }${_hookFile}"
        _docFile="${OUTPUT_DIR}/docker-images/${_dockerImage}/hooks/${_hookFile}.adoc"
        rm -f "${_docFile}"
        echo "  parsing hook ${_hookFile}"
        append_doc "[#devops-ping-identity-devops-hook]"
        append_doc "= Ping Identity DevOps \`${_dockerImage}\` Hook - \`${_hookFile}\`"
        append_doc ""
        # Route each #- line through the same md->adoc converter the README
        # pages use (blockquotes, fences, tables), instead of a raw dump.
        MD_CODE_OPEN=""
        MD_TABLE_OPEN=""
        MD_QUOTE_TYPE=""
        _mdTableCols=""
        while IFS= read -r _hookDocLine; do
            append_md_line "${_hookDocLine}"
        done < <(awk '$0~/^#- /{sub(/^#- /,"");print} /^#-$/{print ""}' "${_hookFilePath}")
        # Close an unterminated fence/table/quote if the hook docs end mid-block
        if [ "${MD_CODE_OPEN}" = "true" ]; then
            append_doc "----"
            MD_CODE_OPEN=""
        fi
        if [ "${MD_TABLE_OPEN}" = "true" ]; then
            append_doc ""
            append_doc "|==="
            MD_TABLE_OPEN=""
        fi
        if [ "${MD_QUOTE_TYPE}" != "" ]; then
            append_doc "===="
            append_doc ""
            MD_QUOTE_TYPE=""
        fi

        append_footer "${_dockerImage}/opt/staging/hooks/${_hookFile}"
    done

    #
    # The following creates a .../product/hooks/README.adoc file as a table of
    # contents for all the hooks for that product.
    #
    # If there are no hooks for that product, then a message will be provided
    # to that effect.
    #
    _docFile="${OUTPUT_DIR}/docker-images/${_dockerImage}/hooks/README.adoc"
    rm -f "${_docFile}"
    append_doc "[#devops-ping-identity-devops-hooks]"
    append_doc "= Ping Identity DevOps \`${_dockerImage}\` Hooks"
    append_doc ""

    if test -z "${_hookFiles}"; then
        append_doc "There are no default hooks defined for the \`${_dockerImage}\` image."
        append_doc ""
        append_doc "Hooks defined by parent images (i.e. pingcommon/pingdatacommon) will be inherited by this image."
        append_footer "${_dockerImage}/Dockerfile"
    else
        append_doc "List of available hooks:"
        append_doc ""
        for _hookFile in ${_hookFiles}; do
            append_doc "* xref:./${_hookFile}.adoc[${_hookFile}]"
        done
        append_doc ""
        append_doc "These hooks will replace hooks defined by parent images (i.e. pingcommon/pingdatacommon)"
        append_footer "${_dockerImage}/opt/staging/hooks"
    fi
}

#
# parse the dockerfile for product
#
parse_dockerfile() {
    _dockerImage="${1}"
    _dockerFile="${DOCKER_BUILD_DIR}/${_dockerImage}/Dockerfile"

    mkdir -p "${OUTPUT_DIR}/docker-images/${_dockerImage}"

    _docFile="${OUTPUT_DIR}/docker-images/${_dockerImage}/README.adoc"
    rm -f "${_docFile}"

    echo "Parsing Dockerfile ${_dockerImage}..."

    docs_image_info "${_dockerImage}" || return 1
    append_page_header "${_dockerImage}"

    # Reset per-image parse state (globals leak across images otherwise)
    _skipNextDoc=""
    _envContinuation="false"
    ENV_DESCRIPTION=""
    ENV_TABLE_ACTIVE="false"
    EXPOSE_PORTS=""
    MD_CODE_OPEN=""
    MD_TABLE_OPEN=""
    MD_QUOTE_TYPE=""
    _mdTableCols=""

    # The #- intro block at the top of each Dockerfile (title, intro prose,
    # Related Docker Images) duplicates the hand content emitted by
    # append_page_header, so it is skipped here. The block ends at the first
    # #- line that starts a real section (## Heading) other than "Related
    # Docker Images", or at the first non-#- line.
    _inIntroBlock="true"

    while read -r line; do
        #
        # Parse the ENV Description
        #   Example: #-- This is the description
        #
        # Each line starting with #-- will be concatenated onto the
        # description until an ENV variable line is found
        #
        if [ "$(echo "${line}" | cut -c-3)" = "#--" ]; then
            ENV_DESCRIPTION="${ENV_DESCRIPTION}$(echo "${line}" | cut -c5-) "
            continue
        fi

        # A hash followed by two forward slashes indicates that the next uncommented line should
        # not be documented.
        if [ "$(echo "${line}" | cut -c-3)" = "#//" ]; then
            _skipNextDoc="true"
            continue
        fi

        #
        # Parse the ENV variable name and value
        #   Example: ENV VARIABLE_ONE=value1 \
        #                VARIABLE_TWO=value2
        #
        # Also supports line continuations with \, so multiple ENV vars can be set in one command
        # Typically ENV lines should use continuations rather than separate ENV statements, to
        # reduce layers in our images, though ENV variables dependent on other variables will need
        # to be defined in separate statements.
        #
        # This logic is unable to handle when the variables values themselves are split onto multiple
        # lines, since it can only check for the \ at the end of the line, so variable values should
        # be kept to a single line to ensure the documentation is valid.
        #
        # Ignore this line if _skipNextDoc is true.
        if [ -n "$_skipNextDoc" ]; then
            _skipNextDoc=""
            continue
        fi
        if [ "$(echo "${line}" | cut -c-4)" = "ENV " ] ||
            [ "$(echo "${line}" | cut -c-12)" = "ONBUILD ENV " ] ||
            [ "${_envContinuation}" = "true" ] && [ "${line}" ] && [ ! "$(echo "${line}" | cut -c-1)" = "#" ]; then
            # Read the variable name before the '='
            if [ "${_envContinuation}" = "true" ]; then
                # Don't expect "ENV" or "ONBUILD ENV"
                ENV_VARIABLE=$(echo "${line}" | sed -e 's/=/x=x/' -e 's/^\(.*\)x=x.*/\1/')
            else
                # Expect "ENV" or "ONBUILD ENV"
                ENV_VARIABLE=$(echo "${line}" | sed -e 's/=/x=x/' -e 's/^.*ENV[[:space:]]\(.*\)x=x.*/\1/')
            fi

            # Read the variable value after the '=', and trim off the ' \' at the end if present
            ENV_VALUE=$(echo "${line}" | sed -e 's/=/x=x/' -e 's/^.*x=x\(.*\)/\1/' -e 's/[[:space:]]\{1,\}\\$//' -e 's/^"\(.*\)"$/\1/')

            # If ENV line ends in slash, the next command will also be an ENV var
            # This isn't able to handle when the variable values themselves are multiline.
            # It assumes that any line continuation is the end of the previous variable.
            if echo "${line}" | grep -q "[[:space:]]\\\\$" > /dev/null 2>&1; then
                _envContinuation="true"
            else
                _envContinuation="false"
            fi

            append_env_table_header

            append_env_variable "${ENV_VARIABLE}" "${ENV_DESCRIPTION}" "${ENV_VALUE}"
            ENV_DESCRIPTION=""

            continue
        fi

        #
        # Parse the EXPOSE values
        #   Example: EXPOSE PORT1 PORT2
        #
        if [ "$(echo "${line}" | cut -c-7)" = "EXPOSE " ] ||
            [ "$(echo "${line}" | cut -c-15)" = "ONBUILD EXPOSE " ]; then
            # shellcheck disable=SC2001
            EXPOSE_PORTS=$(echo "${line}" | sed 's/^.*EXPOSE \(.*\)$/\1/')

            # Close the ENV table before the ports list
            append_env_table_footer
            append_expose_ports "${EXPOSE_PORTS}"

            continue
        fi

        #
        # Parse the remaining lines for "#-" doc lines.
        #
        # Lines starting with '#-' (only one dash) carry markdown-flavored doc
        # content outside the ENV table. Constructs in use across the
        # Dockerfiles (keep this converter in step with any new ones):
        #   #- ## Heading            -> === heading (or IMG_LVL_FIXED level)
        #   #- ``` / ```shell        -> [source,shell] + ---- blocks
        #   #- [text](url)           -> https://...[text] links
        #   #- **bold** / ``code``   -> *bold* / `code`
        #   #- - item / nested lists -> * item / ** item
        #   #- > blockquote          -> > blockquote (asgiidoc passthrough)
        #   #- | pipe tables         -> passthrough (already adoc-shaped)
        #
        if [ "$(echo "${line}" | cut -c-2)" = "#-" ]; then
            # Skip the duplicated intro block (see _inIntroBlock above)
            if [ "${_inIntroBlock}" = "true" ]; then
                case "$(echo "${line}" | cut -c5-)" in
                    "## Related Docker Images"*) ;;
                    "## "*) _inIntroBlock="" ;;
                esac
                continue
            fi

            # Close the ENV table before free-form doc content
            append_env_table_footer

            md=$(echo "$line" | sed \
                -e 's/^\#- //' \
                -e 's/^\#-$//')

            append_md_line "$md"
        else
            # Any non-#- line also ends the intro block
            _inIntroBlock=""
        fi
    done < "${_dockerFile}"

    # Close the ENV table if the Dockerfile ends inside one
    append_env_table_footer

    # Close an unterminated md pipe table the same way (Dockerfile ends
    # without a blank #- line after the rows)
    if [ "${MD_TABLE_OPEN}" = "true" ]; then
        append_doc ""
        append_doc "|==="
        MD_TABLE_OPEN=""
    fi

    # Close an unterminated admonition blockquote the same way
    if [ "${MD_QUOTE_TYPE}" != "" ]; then
        append_doc "===="
        append_doc ""
        MD_QUOTE_TYPE=""
    fi

    append_header
    append_doc "[#devops-docker-container-hook-scripts]"
    append_doc "== Docker Container Hook Scripts"
    append_doc ""
    append_doc "Please go xref:./hooks/README.adoc[here] for details on all ${_dockerImage} hook scripts"
    append_footer "${_dockerImage}/Dockerfile"
}

#
# Convert one markdown-flavored doc line (from a #- comment) to asciidoc and
# append it. Line-oriented by design: code fences toggle source-block mode,
# everything else is transformed inline.
#
append_md_line() {
    _md="${1}"

    # Code fences: open/close a literal block. A language tag becomes the
    # asciidoc [source,...] attribute. A fence line with trailing content
    # (pingcentral: "```shell docker run -Pt \") opens the block and emits the
    # content; the matching "``` shell" variant has a stray space.
    _fenceOpenLang=""
    case "${_md}" in
        '```')
            if [ "${MD_CODE_OPEN}" = "true" ]; then
                append_doc "----"
                MD_CODE_OPEN=""
            else
                append_doc "[source,shell]"
                append_doc "----"
                MD_CODE_OPEN="true"
            fi
            return
            ;;
        '``` shell'*)
            # "``` shell" with a stray space: bare-language opener; the word
            # "shell" after the space is the tag, not content.
            if [ "${MD_CODE_OPEN}" = "true" ]; then
                append_doc "----"
                MD_CODE_OPEN=""
            fi
            append_doc "[source,shell]"
            append_doc "----"
            MD_CODE_OPEN="true"
            _content="${_md#'``` shell'}"
            test -n "${_content}" && append_doc "${_content}"
            return
            ;;
        '``` '* | '```shell '* | '```Bash '* | '```sh '*)
            # Language tag (+ optional stray space) and content on one line:
            # open the block and emit the rest as its first line.
            if [ "${MD_CODE_OPEN}" = "true" ]; then
                # Unclosed previous block: close it before opening a new one.
                append_doc "----"
            fi
            case "${_md}" in
                '```Bash '*) _fenceOpenLang="[source,bash]" ;;
                *) _fenceOpenLang="[source,shell]" ;;
            esac
            append_doc "${_fenceOpenLang}"
            append_doc "----"
            MD_CODE_OPEN="true"
            append_doc "${_md#* }"
            return
            ;;
        '```shell' | '```Bash' | '```sh')
            # Bare-language opener (no content).
            if [ "${MD_CODE_OPEN}" = "true" ]; then
                append_doc "----"
                MD_CODE_OPEN=""
            else
                case "${_md}" in
                    '```Bash') append_doc "[source,bash]" ;;
                    *) append_doc "[source,shell]" ;;
                esac
                append_doc "----"
                MD_CODE_OPEN="true"
            fi
            return
            ;;
    esac
    if [ "${MD_CODE_OPEN}" = "true" ]; then
        append_doc "${_md}"
        return
    fi

    # Links: [text](url) -> url[text]. BRE 'https*:' matches http:/https:
    # (the '?' quantifier is literal in BRE); '[^)]*' stops at the close paren
    # so trailing prose (e.g. ", log in with:") survives.
    # shellcheck disable=SC2001,SC2016
    _md=$(echo "${_md}" | sed -e 's/\[\([^]]*\)\](\(https*:[^)]*\))/\2[\1]/g')

    # Bold: **text** -> *text*
    # shellcheck disable=SC2001,SC2016
    _md=$(echo "${_md}" | sed -e 's/\*\*\([^*]*\)\*\*/\*\1\*/g')

    # Inline code: ``text`` -> `text`
    # shellcheck disable=SC2001,SC2016
    _md=$(echo "${_md}" | sed -e 's/``\([^`]*\)``/`\1`/g')

    # List items: "- " -> "* " (asciidoc bullet). The Dockerfiles use nested
    # "  - " items in a few run blocks, but the hand pages flatten them to "*";
    # match the hand pages (any leading-space depth).
    case "${_md}" in
        '    - '*) _md="* ${_md#    - }" ;;
        '  - '*) _md="* ${_md#  - }" ;;
        '- '*) _md="* ${_md#- }" ;;
    esac

    # Bare URLs in list items render as passthrough text on the portal (+url+)
    # rather than auto-links; match the hand pages. Runs after list conversion.
    case "${_md}" in
        '* http://'* | '* https://'* | '+ http://'*) _md="* +${_md#* }+" ;;
    esac

    # Markdown pipe tables (pingdirectory/pingdirectoryproxy LDAP credential
    # tables). The md rows are "| cell | cell |" with an alignment separator
    # row and an empty header row; asciidoc needs |=== fences and no
    # separator row. A blank #- line closes the table.
    case "${_md}" in
        '|'*)
            # Separator row (| ---: | --- |): every cell is only dashes/colons.
            # Record the alignments, emit nothing. The table opener + col spec
            # is emitted on the first real row instead, so a table with no
            # content rows emits nothing.
            if echo "${_md}" | grep -q '^|[-:[:space:]|]*$' && echo "${_md}" | grep -q -- '-'; then
                _mdTableCols=$(echo "${_md}" | awk -F'|' '{
                    cols = ""
                    for (i = 2; i < NF; i++) {
                        cell = $i
                        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cell)
                        align = "1"
                        if (cell ~ /^:-+:$/) align = "1"
                        else if (cell ~ /^-+:/) align = ">1"
                        else if (cell ~ /:-+:/) align = "^1"
                        cols = (cols == "") ? align : cols "," align
                    }
                    print cols
                }')
                return
            fi
            # Header row: the md tables here have an empty header ("|  |  |");
            # emit the [cols] spec + |=== opener, drop the empty row.
            if [ "${MD_TABLE_OPEN}" != "true" ]; then
                append_doc ""
                append_doc "[cols=\"${_mdTableCols:-1,1}\", options=\"header\"]"
                append_doc "|==="
                MD_TABLE_OPEN="true"
                # Header content: emit only if non-empty after stripping all
                # pipes/spaces (the md tables here have an empty "| | |" header)
                _hdr=$(echo "${_md}" | tr -d '|[:space:]')
                if [ -n "${_hdr}" ]; then
                    append_doc "${_md}"
                fi
                return
            fi
            # Body row: strip the leading space adoc adds implicitly; emit as-is
            append_doc "${_md}"
            return
            ;;
        *)
            if [ "${MD_TABLE_OPEN}" = "true" ]; then
                append_doc ""
                append_doc "|==="
                MD_TABLE_OPEN=""
            fi
            ;;
    esac

    # Blockquote notes (">Note: ...", "> NOTE: ...", ">Example: ..."): emit an
    # admonition block ([NOTE]/[EXAMPLE] + ==== open) on the marker line. Body
    # continues through ">"-prefixed lines and plain prose lines (sources wrap
    # both ways); a blank line, heading, or fence closes it with ====. The
    # caller-side close covers end-of-input. Other "> ..." lines stay as
    # literal adoc blockquotes (pingdataconsole "make sure you have...").
    if [ "${MD_QUOTE_TYPE}" != "" ]; then
        case "${_md}" in
            '## '* | '### '* | '```'*)
                append_doc "===="
                append_doc ""
                MD_QUOTE_TYPE=""
                # fall through: structural line handled below
                ;;
            '>'*)
                _md="${_md#'>'}"
                _md="${_md# }"
                test -z "${_md}" && _md="."
                append_doc "${_md}"
                return
                ;;
            *)
                if [ -z "${_md}" ]; then
                    append_doc "===="
                    append_doc ""
                    MD_QUOTE_TYPE=""
                    return
                fi
                append_doc "${_md}"
                return
                ;;
        esac
    fi
    case "${_md}" in
        '>Note:'* | '>NOTE:'* | '>note:'* | '> Note:'* | '> NOTE:'* | '> note:'*)
            append_doc ""
            append_doc "[NOTE]"
            append_doc "===="
            _md="${_md#'>'}"
            _md="${_md# }"
            # Drop the "Note:"/"NOTE:" marker; the [NOTE] block caption says it
            _md="${_md#Note: }"
            _md="${_md#NOTE: }"
            _md="${_md#note: }"
            MD_QUOTE_TYPE="NOTE"
            ;;
        '>Example:'* | '>EXAMPLE:'* | '> Example:'* | '> EXAMPLE:'*)
            append_doc ""
            append_doc "[EXAMPLE]"
            append_doc "===="
            _md="${_md#'>'}"
            _md="${_md# }"
            _md="${_md#Example: }"
            _md="${_md#EXAMPLE: }"
            MD_QUOTE_TYPE="EXAMPLE"
            ;;
        '>'*)
            # Plain blockquote: keep as-is (adoc passthrough)
            ;;
    esac

    # Headings: every #- "## Heading" / "### Heading" becomes a === section
    # with the deterministic anchor, on every page regardless of the level
    # used by the fixed sections (the hand pages flat-map ### -> === too).
    case "${_md}" in
        '## '*)
            _heading="${_md#'## '}"
            append_doc "[#$(asciidoc_anchor_id "${_heading}")]"
            _md="=== ${_heading}"
            ;;
        '### '*)
            _heading="${_md#'### '}"
            append_doc "[#$(asciidoc_anchor_id "${_heading}")]"
            _md="=== ${_heading}"
            ;;
    esac

    append_doc "${_md}"
}

#
# Derive the deterministic asciidoc anchor id the portal uses for a heading:
# lowercase, alphanumerics kept, everything else -> '-', collapsing runs.
# (Antora/asciidoctor default id derivation, e.g. "Running a PingAccess
# container" -> devops-running-a-pingaccess-container; the devops- prefix
# comes from the sectanchors/ids prefix used by the portal playbook.)
#
asciidoc_anchor_id() {
    _txt="${1}"
    # Matches asciidoctor's id derivation: non-alphanumerics -> '-', but runs
    # within a word-like token collapse first (portal shows "100/sec search
    # rate test" -> 100sec-search-rate-test, i.e. '/' just dropped). Emulate:
    # drop '/', then map remaining non-alnum runs to '-'.
    _id=$(echo "${_txt}" | tr '[:upper:]' '[:lower:]' | sed -e 's|/||g' -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//')
    echo "devops-${_id}"
}

#
# main
#
dockerImages="pingaccess pingfederate pingdirectory pingdatasync
pingbase pingcommon pingdatacommon
pingdataconsole ldap-sdk-tools pingtoolkit
pingdirectoryproxy pingdelegator apache-jmeter pingcentral pingauthorize pingauthorizepap"
#
# Parse the provided arguments, if any
#
while test -n "${1}"; do
    case "${1}" in
        -d | --docker-image)
            shift
            if test -z "${1}"; then
                echo "You must provide name of docker-image(s)"
                usage
            fi
            dockerImages="${1}"
            ;;
        --dry-run)
            # Generation never touches git any more; kept for call-site compat.
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unrecognized option"
            usage
            ;;
    esac
    shift
done

#
# Normalize whitespace of a generated page:
#   - collapse 2+ blank lines to one
#   - exactly one blank after a == / === heading
#   - blank between a prose line and a following list item (* / -), so the
#     list doesn't get absorbed into the paragraph (asciidoc rule)
# Anchors ([#...]) and the = title are NOT followed by a forced blank (the
# title must stay adjacent to :description:, anchors adjacent to headings).
#
normalize_whitespace() {
    _file="${1}"
    awk '
        { lines[NR] = $0 }
        END {
            out = 0
            for (i = 1; i <= NR; i++) {
                line = lines[i]
                blank = (line ~ /^[[:space:]]*$/)
                if (blank && out > 0 && emitted[out] ~ /^[[:space:]]*$/) continue
                out++
                emitted[out] = line
            }
            for (i = 1; i <= out; i++) {
                print emitted[i]
                ishead = (emitted[i] ~ /^==+ /)
                nxt = (i < out) ? emitted[i + 1] : ""
                nxtblank = (nxt ~ /^[[:space:]]*$/)
                nxtlist = (nxt ~ /^[*-] /)
                islist = (emitted[i] ~ /^[*-] /)
                isindent = (emitted[i] ~ /^[[:space:]]/)
                isblank = (emitted[i] ~ /^[[:space:]]*$/)
                iscont = (emitted[i] ~ /^>/)
                if (ishead && i < out && !nxtblank) print ""
                else if (i < out && !nxtblank && nxtlist && !islist && !isindent && !isblank && !iscont) print ""
            }
        }
    ' "${_file}" > "${_file}.norm" && mv "${_file}.norm" "${_file}"
}

mkdir -p "${OUTPUT_DIR}/docker-images"

for dockerImage in ${dockerImages}; do
    echo "Creating docs for '${dockerImage}'"

    if test ! -d "${DOCKER_BUILD_DIR}/${dockerImage}"; then
        echo "Docker Image '${dockerImage}' not found"
        continue
    fi

    parse_dockerfile "${dockerImage}"
    parse_hooks "${dockerImage}"

    # shellcheck disable=SC2044
    for _adoc in $(find "${OUTPUT_DIR}/docker-images/${dockerImage}" -name '*.adoc'); do
        normalize_whitespace "${_adoc}"
    done
done

echo "Docs staged under ${OUTPUT_DIR}/docker-images/"
exit 0
