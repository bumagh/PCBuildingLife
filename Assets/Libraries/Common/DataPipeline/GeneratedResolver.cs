#pragma warning disable 618
#pragma warning disable 612
#pragma warning disable 414
#pragma warning disable 168

namespace Utf8Json.Resolvers
{
    using System;
    using Utf8Json;

    public class GeneratedResolver : global::Utf8Json.IJsonFormatterResolver
    {
        public static readonly global::Utf8Json.IJsonFormatterResolver Instance = new GeneratedResolver();

        GeneratedResolver()
        {

        }

        public global::Utf8Json.IJsonFormatter<T> GetFormatter<T>()
        {
            return FormatterCache<T>.formatter;
        }

        static class FormatterCache<T>
        {
            public static readonly global::Utf8Json.IJsonFormatter<T> formatter;

            static FormatterCache()
            {
                var f = GeneratedResolverGetFormatterHelper.GetFormatter(typeof(T));
                if (f != null)
                {
                    formatter = (global::Utf8Json.IJsonFormatter<T>)f;
                }
            }
        }
    }

    internal static class GeneratedResolverGetFormatterHelper
    {
        static readonly global::System.Collections.Generic.Dictionary<Type, int> lookup;

        static GeneratedResolverGetFormatterHelper()
        {
            lookup = new global::System.Collections.Generic.Dictionary<Type, int>(3)
            {
                {typeof(global::Article[]), 0 },
                {typeof(global::Article), 1 },
                {typeof(global::Range), 2 },
            };
        }

        internal static object GetFormatter(Type t)
        {
            int key;
            if (!lookup.TryGetValue(t, out key)) return null;

            switch (key)
            {
                case 0: return new global::Utf8Json.Formatters.ArrayFormatter<global::Article>();
                case 1: return new Utf8Json.Formatters.ArticleFormatter();
                case 2: return new Utf8Json.Formatters.RangeFormatter();
                default: return null;
            }
        }
    }
}

#pragma warning disable 168
#pragma warning restore 414
#pragma warning restore 618
#pragma warning restore 612

#pragma warning disable 618
#pragma warning disable 612
#pragma warning disable 414
#pragma warning disable 219
#pragma warning disable 168

namespace Utf8Json.Formatters
{
    using System;
    using Utf8Json;


    public sealed class ArticleFormatter : global::Utf8Json.IJsonFormatter<global::Article>
    {
        readonly global::Utf8Json.Internal.AutomataDictionary ____keyMapping;
        readonly byte[][] ____stringByteKeys;

        public ArticleFormatter()
        {
            this.____keyMapping = new global::Utf8Json.Internal.AutomataDictionary()
            {
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("id"), 0},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("count"), 1},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("subArticles"), 2},
            };

            this.____stringByteKeys = new byte[][]
            {
                JsonWriter.GetEncodedPropertyNameWithBeginObject("id"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("count"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("subArticles"),
                
            };
        }

        public void Serialize(ref JsonWriter writer, global::Article value, global::Utf8Json.IJsonFormatterResolver formatterResolver)
        {
            if (value == null)
            {
                writer.WriteNull();
                return;
            }
            

            writer.WriteRaw(this.____stringByteKeys[0]);
            writer.WriteInt32(value.id);
            writer.WriteRaw(this.____stringByteKeys[1]);
            writer.WriteInt32(value.count);
            writer.WriteRaw(this.____stringByteKeys[2]);
            formatterResolver.GetFormatterWithVerify<global::Article[]>().Serialize(ref writer, value.subArticles, formatterResolver);
            
            writer.WriteEndObject();
        }

        public global::Article Deserialize(ref JsonReader reader, global::Utf8Json.IJsonFormatterResolver formatterResolver)
        {
            if (reader.ReadIsNull())
            {
                return null;
            }
            

            var __id__ = default(int);
            var __id__b__ = false;
            var __count__ = default(int);
            var __count__b__ = false;
            var __subArticles__ = default(global::Article[]);
            var __subArticles__b__ = false;

            var ____count = 0;
            reader.ReadIsBeginObjectWithVerify();
            while (!reader.ReadIsEndObjectWithSkipValueSeparator(ref ____count))
            {
                var stringKey = reader.ReadPropertyNameSegmentRaw();
                int key;
                if (!____keyMapping.TryGetValueSafe(stringKey, out key))
                {
                    reader.ReadNextBlock();
                    goto NEXT_LOOP;
                }

                switch (key)
                {
                    case 0:
                        __id__ = reader.ReadInt32();
                        __id__b__ = true;
                        break;
                    case 1:
                        __count__ = reader.ReadInt32();
                        __count__b__ = true;
                        break;
                    case 2:
                        __subArticles__ = formatterResolver.GetFormatterWithVerify<global::Article[]>().Deserialize(ref reader, formatterResolver);
                        __subArticles__b__ = true;
                        break;
                    default:
                        reader.ReadNextBlock();
                        break;
                }

                NEXT_LOOP:
                continue;
            }

            var ____result = new global::Article();
            if(__id__b__) ____result.id = __id__;
            if(__count__b__) ____result.count = __count__;
            if(__subArticles__b__) ____result.subArticles = __subArticles__;

            return ____result;
        }
    }


    public sealed class RangeFormatter : global::Utf8Json.IJsonFormatter<global::Range>
    {
        readonly global::Utf8Json.Internal.AutomataDictionary ____keyMapping;
        readonly byte[][] ____stringByteKeys;

        public RangeFormatter()
        {
            this.____keyMapping = new global::Utf8Json.Internal.AutomataDictionary()
            {
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("min"), 0},
                { JsonWriter.GetEncodedPropertyNameWithoutQuotation("max"), 1},
            };

            this.____stringByteKeys = new byte[][]
            {
                JsonWriter.GetEncodedPropertyNameWithBeginObject("min"),
                JsonWriter.GetEncodedPropertyNameWithPrefixValueSeparator("max"),
                
            };
        }

        public void Serialize(ref JsonWriter writer, global::Range value, global::Utf8Json.IJsonFormatterResolver formatterResolver)
        {
            if (value == null)
            {
                writer.WriteNull();
                return;
            }
            

            writer.WriteRaw(this.____stringByteKeys[0]);
            writer.WriteSingle(value.min);
            writer.WriteRaw(this.____stringByteKeys[1]);
            writer.WriteSingle(value.max);
            
            writer.WriteEndObject();
        }

        public global::Range Deserialize(ref JsonReader reader, global::Utf8Json.IJsonFormatterResolver formatterResolver)
        {
            if (reader.ReadIsNull())
            {
                return null;
            }
            

            var __min__ = default(float);
            var __min__b__ = false;
            var __max__ = default(float);
            var __max__b__ = false;

            var ____count = 0;
            reader.ReadIsBeginObjectWithVerify();
            while (!reader.ReadIsEndObjectWithSkipValueSeparator(ref ____count))
            {
                var stringKey = reader.ReadPropertyNameSegmentRaw();
                int key;
                if (!____keyMapping.TryGetValueSafe(stringKey, out key))
                {
                    reader.ReadNextBlock();
                    goto NEXT_LOOP;
                }

                switch (key)
                {
                    case 0:
                        __min__ = reader.ReadSingle();
                        __min__b__ = true;
                        break;
                    case 1:
                        __max__ = reader.ReadSingle();
                        __max__b__ = true;
                        break;
                    default:
                        reader.ReadNextBlock();
                        break;
                }

                NEXT_LOOP:
                continue;
            }

            var ____result = new global::Range();
            if(__min__b__) ____result.min = __min__;
            if(__max__b__) ____result.max = __max__;

            return ____result;
        }
    }

}

#pragma warning disable 168
#pragma warning restore 219
#pragma warning restore 414
#pragma warning restore 618
#pragma warning restore 612
