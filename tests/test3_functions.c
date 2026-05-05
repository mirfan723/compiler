// Test 3: User-defined functions, parameters, and return values
int add(int a, int b) {
    int result;
    result = a + b;
    return result;
}

int factorial(int n) {
    int result;
    result = 1;
    int i;
    i = 1;
    while (i <= n) {
        result = result * i;
        i = i + 1;
    }
    return result;
}

int max(int a, int b) {
    if (a > b) {
        return a;
    } else {
        return b;
    }
}

int main() {
    int s;
    int f;
    int m;

    s = add(3, 4);
    f = factorial(5);
    m = max(10, 20);

    int combined;
    combined = add(s, m);

    return 0;
}
