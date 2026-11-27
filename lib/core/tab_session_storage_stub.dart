// Fora da web o TabSessionStorage não é usado.
String? read(String key) => throw UnsupportedError('Só na web');

void write(String key, String value) => throw UnsupportedError('Só na web');

void remove(String key) => throw UnsupportedError('Só na web');

void removeShared(String key) => throw UnsupportedError('Só na web');
