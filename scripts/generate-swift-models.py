#!/usr/bin/env python3
import json, pathlib, sys
root=pathlib.Path(__file__).resolve().parents[1]
schema=json.loads((root/'packages/shared-types/schema.json').read_text())
extra=[]
def typename(name, field, spec):
 if 'anyOf' in spec: return typename(name,field,spec['anyOf'][0])+'?'
 if 'enum' in spec:
  n=name+field[0].upper()+field[1:]
  extra.append('public enum '+n+': String, Codable, Sendable { '+ '; '.join('case `'+v+'`' for v in spec['enum'])+' }')
  return n
 if spec.get('type')=='object':
  n=name+field[0].upper()+field[1:]; extra.append(struct(n,spec)); return n
 if spec.get('type')=='array':return '['+typename(name,field,spec['items'])+']'
 if '$ref' in spec:return spec['$ref'].split('/')[-1]
 if spec.get('format')=='uuid': return 'UUID'
 if 'const' in spec:return 'Int'
 return {'string':'String','number':'Double','integer':'Int','boolean':'Bool'}[spec['type']]
def struct(name,spec):
 fields=[(f,typename(name,f,s)) for f,s in spec['properties'].items()]
 lines=['public struct '+name+': Codable, Equatable, Sendable {']
 lines += ['    public var '+f+': '+t for f,t in fields]
 lines += ['    public init('+', '.join(f+': '+t for f,t in fields)+') {']
 lines += ['        self.'+f+' = '+f for f,t in fields]
 lines += ['    }']
 versions=[f for f,s in spec['properties'].items() if 'const' in s]
 lines += ['    enum CodingKeys: String, CodingKey { case '+', '.join(f for f,t in fields)+' }','    public init(from decoder: Decoder) throws {','        let c = try decoder.container(keyedBy: CodingKeys.self)']
 for f,t in fields:
  decode_type='Optional<'+t[:-1]+'>' if t.endswith('?') else t
  lines += ['        '+f+' = try c.decode('+decode_type+'.self, forKey: .'+f+')']
  if f in versions:lines += ['        guard '+f+' == 1 else { throw ContractError.unsupportedVersion('+f+') }']
 lines += ['    }','    public func encode(to encoder: Encoder) throws {','        var c = encoder.container(keyedBy: CodingKeys.self)']
 lines += ['        try c.encode('+f+', forKey: .'+f+')' for f,t in fields]
 lines += ['    }']
 lines += ['}'];return '\n'.join(lines)
models=[struct(n,s) for n,s in schema['definitions'].items()]
models.append(struct('EcosystemFixture',schema))
content='// Generated from packages/shared-types/schema.json.\nimport Foundation\n\npublic enum ContractError: Error { case unsupportedVersion(Int) }\n\n'+'\n\n'.join(extra+models)+'\n'
outputs={'apps/studio/NTOFoundation/Sources/NTOFoundation/Models.swift':content,'apps/studio/NTOFoundation/Tests/NTOFoundationTests/Fixtures/ecosystem.json':(root/'packages/shared-types/fixtures/ecosystem.json').read_text()}
for path,content in outputs.items():
 p=root/path
 if '--check' in sys.argv:
  if not p.exists() or p.read_text()!=content:raise SystemExit('Generated models stale: '+path)
 else:p.parent.mkdir(parents=True,exist_ok=True);p.write_text(content)
