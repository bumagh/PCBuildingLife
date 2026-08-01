using System;

enum CoreCompSlot
{
    Case,
    Power,
    VideoCard,
    MotherBoard,
    CPU,
    RAM1,
    RAM2,
    RAM3,
    RAM4,
    SSD1,
    SSD2,
    HDD1,
    HDD2,
    M2,
    COOLER
}

enum CoreCompType
{
    Case,
    Power,
    VideoCard,
    MotherBoard,
    CPU,
    RAM,
    SSD,
    HDD,
    M2,
    COOLER
}
class CoreCompEnum
{
    public static CoreCompType GetComponentType(CoreCompSlot slot)
    {
        switch (slot)
        {
            case CoreCompSlot.Case: return CoreCompType.Case;
            case CoreCompSlot.Power: return CoreCompType.Power;
            case CoreCompSlot.VideoCard: return CoreCompType.VideoCard;
            case CoreCompSlot.MotherBoard: return CoreCompType.MotherBoard;
            case CoreCompSlot.CPU: return CoreCompType.CPU;
            case CoreCompSlot.RAM1:
            case CoreCompSlot.RAM2:
            case CoreCompSlot.RAM3:
            case CoreCompSlot.RAM4:
                return CoreCompType.RAM;
            case CoreCompSlot.SSD1:
            case CoreCompSlot.SSD2:
                return CoreCompType.SSD;
            case CoreCompSlot.HDD1:
            case CoreCompSlot.HDD2:
                return CoreCompType.HDD;
            case CoreCompSlot.M2: return CoreCompType.M2;
            case CoreCompSlot.COOLER: return CoreCompType.COOLER;
            default:
                throw new ArgumentException($"Invalid slot: {slot}");
        }
    }
}