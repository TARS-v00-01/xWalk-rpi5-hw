#include <thread>

int xwalkThreadProbeValue = 0;

void updateThreadProbe()
{
    for (int index = 0; index < 10'000; ++index)
    {
        ++xwalkThreadProbeValue;
    }
}

int main()
{
    std::thread first(updateThreadProbe);
    std::thread second(updateThreadProbe);
    first.join();
    second.join();
    return 0;
}
