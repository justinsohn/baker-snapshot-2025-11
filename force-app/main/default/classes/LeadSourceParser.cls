public class LeadSourceParser {
  private static final List<String> END_TOKENS = new List<String>{
    'referral',
    'campaign',
    'pageid'
  };
  private static final String END_TOKEN_PATTERN = String.join(END_TOKENS, '|');
  private static final String REGEX =
    '(?i)source\\s*:?\\s*(.*?)\\s*(?=(' +
    END_TOKEN_PATTERN +
    ')\\b|$)';
  private static final String DEFAULT_VALUE = 'No Lead Source';

  private static Integer recursionDepth = 0;

  public static Boolean runOnce() {
    if (recursionDepth > 0) {
      return true;
    }
    recursionDepth++;
    return false;
  }

  public static void release() {
    recursionDepth = 0;
  }

  public static String parse(String detail) {
    if (String.isBlank(detail)) {
      return DEFAULT_VALUE;
    }

    Pattern pattern = Pattern.compile(REGEX);
    Matcher matcher = pattern.matcher(detail);

    if (matcher.find()) {
      String parsedValue = matcher.group(1);
      if (parsedValue == null) {
        return null;
      }
      parsedValue = parsedValue.trim();
      if (parsedValue.startsWith('/')) {
        parsedValue = parsedValue.substring(1);
      }
      return normalize(parsedValue);
    }

    return '';
  }

  private static String normalize(String value) {
    if (String.isBlank(value)) {
      return DEFAULT_VALUE;
    }

    String normalized = value.trim();
    normalized = collapseDuplicateTail(normalized);
    normalized = stripTrailingTokens(normalized);
    normalized = removeSuffixIgnoreCase(normalized, 'poolcpc', false);
    normalized = removeSuffixIgnoreCase(normalized, 'cpc', false);
    normalized = removeSuffixIgnoreCase(normalized, 'extension', false);
    normalized = removeSuffixIgnoreCase(normalized, 'local', true);
    normalized = removeSuffixIgnoreCase(normalized, 'search', true);
    normalized = normalized.replaceAll('\\s+', ' ').trim();
    return normalized.length() == 0 ? DEFAULT_VALUE : normalized;
  }

  private static String collapseDuplicateTail(String input) {
    if (String.isBlank(input)) {
      return input;
    }

    String value = input;
    Integer length = value.length();
    Integer maxSegment = Math.min(20, length / 2);

    for (Integer segment = maxSegment; segment > 0; segment--) {
      Integer start = length - (segment * 2);
      if (start < 0) {
        continue;
      }
      String first = value.substring(start, start + segment);
      String second = value.substring(start + segment);
      if (first.equalsIgnoreCase(second)) {
        return value.substring(0, start + segment);
      }
    }

    return value;
  }

  private static String removeSuffixIgnoreCase(
    String value,
    String suffix,
    Boolean requireAttached
  ) {
    if (String.isBlank(value) || String.isBlank(suffix)) {
      return value;
    }

    Integer suffixLength = suffix.length();
    if (value.length() < suffixLength) {
      return value;
    }

    String tail = value.substring(value.length() - suffixLength);
    if (!tail.equalsIgnoreCase(suffix)) {
      return value;
    }

    if (requireAttached && value.length() > suffixLength) {
      String preceding = value.substring(
        value.length() - suffixLength - 1,
        value.length() - suffixLength
      );
      if (preceding == ' ') {
        return value;
      }
    }

    return value.substring(0, value.length() - suffixLength).trim();
  }

  private static String stripTrailingTokens(String value) {
    if (String.isBlank(value)) {
      return value;
    }

    String result = value;
    Boolean removedToken = true;

    while (removedToken && !String.isBlank(result)) {
      removedToken = false;
      for (String token : END_TOKENS) {
        if (endsWithIgnoreCase(result, token)) {
          result = result.substring(0, result.length() - token.length()).trim();
          removedToken = true;
          break;
        }
      }
    }

    return result;
  }

  private static Boolean endsWithIgnoreCase(String value, String suffix) {
    if (String.isBlank(value) || String.isBlank(suffix)) {
      return false;
    }

    Integer valueLength = value.length();
    Integer suffixLength = suffix.length();

    if (valueLength < suffixLength) {
      return false;
    }

    String tail = value.substring(valueLength - suffixLength);
    return tail.equalsIgnoreCase(suffix);
  }
}