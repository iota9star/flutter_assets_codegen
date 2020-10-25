const extensionTemplate = """
extension {{extensionName}} on {{className}} {
    {{#asset.assets}}
    
    /// ![{{{baseName}}}][{{{filePath}}}]
    {{#isDir}}
    static final {{className}} {{fieldName}} = const {{className}}._();
    {{/isDir}}
    {{^isDir}}
    static final String {{fieldName}} = "{{{path}}}";
    {{/isDir}}
    {{/asset.assets}}
}
{{#asset.assets}}
{{#isDir}}
{{> assetsLayout}}
{{/isDir}}
{{/asset.assets}}
""";
const assetsTemplate = """
/// [{{{baseName}}}]({{{filePath}}})
class {{className}} {
    const {{className}}._();
    {{#assets}}
    
    /// ![{{{baseName}}}][{{{filePath}}}]
    {{#isDir}}
    final {{className}} {{fieldName}} = const {{className}}._();
    {{/isDir}}
    {{^isDir}}
    final String {{fieldName}} = "{{{path}}}";
    {{/isDir}}
    {{/assets}}
}
{{#assets}}
{{#isDir}}
{{> assetsLayout}}
{{/isDir}}
{{/assets}}
""";

const pubspecEmptyTemplate = """

flutter:
  assets:
    {{#paths}}
    - {{{.}}}
    {{/paths}}
""";

const pubspecAssetsTemplate = """
{{{indent}}}assets:
{{#paths}}
{{{indent}}}{{{indent}}}- {{{.}}}
{{/paths}}
""";
