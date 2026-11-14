-- Copyright 2026 Han Li and contributors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- Reads the attached containers of a WiX Burn bundle, the Windows EXE installers that
-- python.org publishes. The layout follows WiX v3 src/burn/engine/section.cpp: a .wixburn
-- section of the PE file holds the bundle header, and the containers (CAB files) follow the
-- engine in the file. The bundle manifest is the XML inside the UX container.
local bundle = {}

local BURN_SECTION_MAGIC = 0x00F14300
local BURN_SECTION_VERSION = 2

local function readBytes(file, offset, count)
    file:seek("set", offset)
    local data = file:read(count)
    if data == nil or #data ~= count then
        error("The installer ends early at byte " .. offset)
    end
    return data
end

local function readUInt16(file, offset)
    local data = readBytes(file, offset, 2)
    return data:byte(1) + data:byte(2) * 256
end

local function readUInt32(file, offset)
    local data = readBytes(file, offset, 4)
    return data:byte(1) + data:byte(2) * 256 + data:byte(3) * 65536 + data:byte(4) * 16777216
end

-- Returns the byte range of every attached container, keyed by container index:
-- { offset = <first byte>, size = <length> }. Index 0 is the UX container.
function bundle.containers(file)
    if readBytes(file, 0, 2) ~= "MZ" then
        error("The installer is not a Windows executable")
    end
    local peOffset = readUInt32(file, 0x3C)
    if readBytes(file, peOffset, 4) ~= "PE\0\0" then
        error("The installer has no PE header")
    end
    local sectionCount = readUInt16(file, peOffset + 6)
    local optionalHeaderSize = readUInt16(file, peOffset + 20)
    local sectionTable = peOffset + 24 + optionalHeaderSize
    local burnHeader = nil
    for index = 0, sectionCount - 1 do
        local entry = sectionTable + 40 * index
        -- Section names are 8 bytes, so ".wixburn" fills the name exactly.
        if readBytes(file, entry, 8) == ".wixburn" then
            burnHeader = readUInt32(file, entry + 20)
        end
    end
    if burnHeader == nil then
        error("The installer has no Burn section")
    end
    if
        readUInt32(file, burnHeader) ~= BURN_SECTION_MAGIC
        or readUInt32(file, burnHeader + 4) ~= BURN_SECTION_VERSION
    then
        error("The installer has an unsupported Burn section")
    end

    local stubSize = readUInt32(file, burnHeader + 24)
    local signatureOffset = readUInt32(file, burnHeader + 32)
    local signatureSize = readUInt32(file, burnHeader + 36)
    local count = readUInt32(file, burnHeader + 44)
    local sizes = {}
    for index = 0, count - 1 do
        sizes[index] = readUInt32(file, burnHeader + 48 + 4 * index)
    end

    local engineSize = stubSize + sizes[0]
    if signatureOffset ~= 0 then
        engineSize = signatureOffset + signatureSize
    end

    local ranges = {}
    for index = 0, count - 1 do
        local offset = stubSize
        if index > 0 then
            offset = engineSize
            for earlier = 1, index - 1 do
                offset = offset + sizes[earlier]
            end
        end
        ranges[index] = { offset = offset, size = sizes[index] }
    end
    return ranges
end

-- Returns the bytes of a byte range, or raises an error when the installer is too short.
function bundle.readRange(file, range)
    return readBytes(file, range.offset, range.size)
end

-- Reads the bundle manifest. Returns the attached container index that holds the packages,
-- and the embedded packages of that container as { file = <MSI name>, source = <CAB member> }.
function bundle.parseManifest(text)
    local primaryId = nil
    local attachedIndex = nil
    for tag in text:gmatch("<Container[%s>][^>]*>") do
        if tag:find('Attached="yes"', 1, true) and tag:find('Primary="yes"', 1, true) then
            primaryId = tag:match(' Id="([^"]*)"')
            attachedIndex = tonumber(tag:match('AttachedIndex="(%d+)"'))
        end
    end
    if primaryId == nil or attachedIndex == nil then
        error("The bundle manifest has no primary attached container")
    end

    local payloads = {}
    for tag in text:gmatch("<Payload[%s>][^>]*>") do
        if tag:find('Container="' .. primaryId .. '"', 1, true) and tag:find('Packaging="embedded"', 1, true) then
            payloads[#payloads + 1] = {
                file = tag:match('FilePath="([^"]*)"'),
                source = tag:match('SourcePath="([^"]*)"'),
            }
        end
    end
    return { attachedIndex = attachedIndex, payloads = payloads }
end

return bundle
